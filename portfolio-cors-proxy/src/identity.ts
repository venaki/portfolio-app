import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey, type JWTPayload } from 'jose';
import { ApiError } from './common';

const firebaseKeys = createRemoteJWKSet(new URL(
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
), { timeoutDuration: 5_000 });
const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'), { timeoutDuration: 5_000 });

export interface FirebaseIdentity { uid: string; googleSub: string }

export async function verifyFirebaseToken(token: string, projectId: string, keys: JWTVerifyGetKey = firebaseKeys): Promise<FirebaseIdentity> {
  try {
    const { payload, protectedHeader } = await jwtVerify(token, keys, {
      algorithms: ['RS256'], issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId, requiredClaims: ['exp', 'iat', 'sub', 'auth_time'],
    });
    validateTimes(payload);
    const firebase = payload.firebase as { identities?: Record<string, unknown>; sign_in_provider?: unknown } | undefined;
    const googleIds = firebase?.identities?.['google.com'];
    if (typeof protectedHeader.kid !== 'string' || !protectedHeader.kid || payload.aud !== projectId ||
      typeof payload.sub !== 'string' || !payload.sub || payload.sub.length > 128 || firebase?.sign_in_provider !== 'google.com' ||
      !Array.isArray(googleIds) || googleIds.length !== 1 || typeof googleIds[0] !== 'string' || !googleIds[0]) throw new Error();
    return { uid: payload.sub, googleSub: googleIds[0] };
  } catch { throw new ApiError(401, 'invalid_identity_token'); }
}

export async function verifyGoogleToken(token: string, clientId: string, nonce: string, keys: JWTVerifyGetKey = googleKeys): Promise<string> {
  try {
    const { payload, protectedHeader } = await jwtVerify(token, keys, {
      algorithms: ['RS256'], issuer: ['https://accounts.google.com', 'accounts.google.com'],
      audience: clientId, requiredClaims: ['exp', 'iat', 'sub', 'nonce'],
    });
    if (typeof protectedHeader.kid !== 'string' || !protectedHeader.kid || payload.aud !== clientId ||
      (payload.azp !== undefined && payload.azp !== clientId) || typeof payload.sub !== 'string' ||
      !payload.sub || payload.nonce !== nonce || (payload.iat ?? Infinity) > Date.now() / 1000) throw new Error();
    return payload.sub;
  } catch { throw new ApiError(401, 'invalid_google_token'); }
}

function validateTimes(payload: JWTPayload): void {
  const now = Date.now() / 1000;
  if (typeof payload.iat !== 'number' || payload.iat > now ||
    typeof payload.auth_time !== 'number' || !Number.isFinite(payload.auth_time) ||
    payload.auth_time > now || payload.auth_time < 0) throw new Error();
}
