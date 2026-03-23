#!/bin/bash
# Portfolio App — 웹 빌드 + GitHub Pages 배포 스크립트
set -e

echo "📦 웹 빌드 중..."
npx expo export --platform web

echo "🔤 폰트 CDN 패치 중..."
# index.html에 Google Fonts CDN 추가
sed -i '' 's|<link rel="icon" href="/portfolio-app/favicon.ico" /></head>|<link rel="icon" href="/portfolio-app/favicon.ico" />\
  <link rel="preconnect" href="https://fonts.googleapis.com" />\
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />\
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600\&family=JetBrains+Mono:wght@400;500;600;700\&family=Newsreader:wght@400;500\&display=swap" rel="stylesheet" />\
  <style>\
    @font-face { font-family: '"'"'Inter_400Regular'"'"'; src: local('"'"'Inter'"'"'); font-weight: 400; }\
    @font-face { font-family: '"'"'Inter_500Medium'"'"'; src: local('"'"'Inter'"'"'); font-weight: 500; }\
    @font-face { font-family: '"'"'Inter_600SemiBold'"'"'; src: local('"'"'Inter'"'"'); font-weight: 600; }\
    @font-face { font-family: '"'"'JetBrainsMono_400Regular'"'"'; src: local('"'"'JetBrains Mono'"'"'); font-weight: 400; }\
    @font-face { font-family: '"'"'JetBrainsMono_500Medium'"'"'; src: local('"'"'JetBrains Mono'"'"'); font-weight: 500; }\
    @font-face { font-family: '"'"'JetBrainsMono_600SemiBold'"'"'; src: local('"'"'JetBrains Mono'"'"'); font-weight: 600; }\
    @font-face { font-family: '"'"'JetBrainsMono_700Bold'"'"'; src: local('"'"'JetBrains Mono'"'"'); font-weight: 700; }\
    @font-face { font-family: '"'"'Newsreader_400Regular'"'"'; src: local('"'"'Newsreader'"'"'); font-weight: 400; }\
    @font-face { font-family: '"'"'Newsreader_500Medium'"'"'; src: local('"'"'Newsreader'"'"'); font-weight: 500; }\
  </style>\
  </head>|' dist/index.html

echo "🗑️ 불필요한 폰트 파일 제거..."
rm -rf dist/assets/node_modules

echo "📄 GitHub Pages 설정..."
touch dist/.nojekyll
cp dist/index.html dist/404.html

echo "🚀 GitHub Pages 배포 중..."
npx gh-pages -d dist --dotfiles

echo "✅ 배포 완료! https://venaki.github.io/portfolio-app"
