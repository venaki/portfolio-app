import { ApiError, challengeFor, errorResponse, json, readBody, stringField } from './common';

export interface Attempt {
  origin: string;
  challenge: string;
  nonce: string;
  redirectUri: string;
  createdAt: number;
  expiresAt: number;
  phase: 'pending' | 'exchanging' | 'exchanged' | 'consumed';
  refreshToken?: string;
  googleSub?: string;
}

export interface StoredToken { refreshToken: string; googleSub: string; version: string }

/** Only the Worker can invoke these routes. Claims commit before network I/O. */
export class AuthState {
  constructor(private readonly ctx: DurableObjectState) {}

  async fetch(request: Request): Promise<Response> {
    try {
      const body = await readBody(request);
      const action = new URL(request.url).pathname;
      const proof = action === '/claim-exchange' || action === '/claim-complete'
        ? await challengeFor(stringField(body, 'verifier', 128)) : null;
      const result = await this.ctx.storage.transaction(async (tx) => {
        if (action === '/create') {
          if (await tx.get('attempt')) throw new ApiError(409, 'attempt_exists');
          const attempt = body as unknown as Attempt;
          await tx.put('attempt', attempt);
          await tx.setAlarm(attempt.expiresAt);
          return { ok: true };
        }
        if (action === '/put-token') {
          const revokedBefore = await tx.get<number>('revokedBefore');
          if (revokedBefore !== undefined &&
            (typeof body.attemptStartedAt !== 'number' || body.attemptStartedAt <= revokedBefore)) {
            throw new ApiError(401, 'session_changed');
          }
          await tx.put('token', body as unknown as StoredToken);
          return { ok: true };
        }
        if (action === '/get-token') {
          const token = await tx.get<StoredToken>('token');
          if (!token) throw new ApiError(401, 'relogin_required');
          return token;
        }
        if (action === '/revoke') {
          await tx.delete('token');
          await tx.put('revokedBefore', Date.now());
          return { ok: true };
        }
        if (action === '/delete-token-version') {
          const token = await tx.get<StoredToken>('token');
          if (token?.version === body.version) await tx.delete('token');
          return { ok: true };
        }
        if (action === '/check-token-version') {
          const token = await tx.get<StoredToken>('token');
          if (!token || token.version !== body.version) throw new ApiError(401, 'session_changed');
          return { ok: true };
        }
        const attempt = await tx.get<Attempt>('attempt');
        if (!attempt || attempt.expiresAt <= Date.now() || attempt.phase === 'consumed') throw new ApiError(401, 'attempt_expired');
        if (action === '/inspect') {
          if (attempt.phase !== 'pending') throw new ApiError(409, 'attempt_used');
          return { origin: attempt.origin };
        }
        if (action === '/claim-exchange' || action === '/claim-complete') {
          if (attempt.origin !== body.origin || attempt.challenge !== proof) throw new ApiError(403, 'invalid_attempt_proof');
        }
        if (action === '/claim-exchange') {
          if (attempt.phase !== 'pending') throw new ApiError(409, 'attempt_used');
          await tx.put('attempt', { ...attempt, phase: 'exchanging' });
          return attempt;
        }
        if (action === '/finish-exchange') {
          if (attempt.phase !== 'exchanging') throw new ApiError(409, 'attempt_used');
          await tx.put('attempt', {
            ...attempt, phase: 'exchanged', refreshToken: stringField(body, 'refreshToken'),
            googleSub: stringField(body, 'googleSub', 255),
          });
          return { ok: true };
        }
        if (action === '/claim-complete') {
          if (attempt.phase !== 'exchanged') throw new ApiError(409, 'attempt_used');
          if (attempt.googleSub !== body.googleSub) throw new ApiError(403, 'identity_mismatch');
          // Retain the tombstone until expiry so an old state cannot be initialized again.
          await tx.put('attempt', { ...attempt, phase: 'consumed', refreshToken: undefined });
          return { refreshToken: attempt.refreshToken, googleSub: attempt.googleSub, attemptStartedAt: attempt.createdAt };
        }
        throw new ApiError(404, 'not_found');
      });
      return json(result);
    } catch (error) { return errorResponse(error); }
  }

  async alarm(): Promise<void> { await this.ctx.storage.deleteAll(); }
}
