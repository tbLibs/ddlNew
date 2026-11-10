// Offline provider stubs: validates language options and local document metadata, not live challenges.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
for(const language of ['zh-Hans','zh-Hant','en']) {
 for(const provider of ['tx','alione','alitwo']) {
  const source=fs.readFileSync('ddlNew/Resources/LoginVerification/noa_captcha_'+provider+'.html','utf8');
  let captured;
  const context={document:{documentElement:{clientWidth:375},title:''},console};
  context.window={appCaptchaLocalization:{language,title:'test-title'},innerWidth:375,initAliyunCaptcha: options=>captured=options};
  context.TencentCaptcha=function(id,callback,options){captured=options;this.show=()=>{};};
  vm.createContext(context);
  for(const match of source.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)){if(match[1].trim())vm.runInContext(match[1],context);}
  if(provider==='tx')context.window.onload();
  assert(captured,'provider options captured');
  assert.equal(context.document.documentElement.lang,language);
  assert.equal(context.document.title,'test-title');
  const expected=provider==='tx'?{'zh-Hans':'zh-cn','zh-Hant':'zh-tw',en:'en'}:{'zh-Hans':'cn','zh-Hant':'tw',en:'en'};
  assert.equal(captured[provider==='tx'?'userLanguage':'language'],expected[language]);
  if(provider!=='tx'){assert.equal(captured.prefix,'xxslmpl');assert.equal(captured.region,'sgp');assert.equal(captured.mode,'embed');}
  console.log(provider,language,'PASS');
 }
}

// Native bridge must inject only into the main frame before provider scripts run.
const native = fs.readFileSync('ddlNew/Features/Login/Views/LoginCaptchaWebView.swift', 'utf8');
assert(native.includes('"language": L10n.languageCode'));
assert(native.includes('injectionTime: .atDocumentStart, forMainFrameOnly: true'));
assert(native.includes('JSONSerialization.data(withJSONObject: localization)'));
// Keep the existing callback origin restrictions and provider identity contracts.
assert(native.includes('message.frameInfo.isMainFrame'));
assert(native.includes('message.frameInfo.securityOrigin.protocol == "file"'));
console.log('Native injection and callback guards PASS');
