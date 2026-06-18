import Foundation

/// Configuration snapshot used to build the privacy JS injected at document start.
struct PrivacyConfig {
    var enabled: Bool = false           // master privacy switch (or incognito)
    var canvasNoise: Bool = false
    var webglSpoof: Bool = false
    var audioNoise: Bool = false
    var limitFonts: Bool = false
    var rectsNoise: Bool = false
    var reduceTiming: Bool = false
    var hideMedia: Bool = false
    var hideBattery: Bool = false
    var blockSensors: Bool = false
    var spoofLanguage: Bool = false
    var language: String = "en-US"
    var spoofTimezone: Bool = false
    var timezone: String = "UTC"
    var spoofScreen: Bool = false
    var spoofGeo: Bool = false
    var geoDeny: Bool = true            // true = deny, false = fake coords
    var geoLat: Double = 40.7128
    var geoLon: Double = -74.0060
    var blockWebRTC: Bool = false
    var hardenNavigator: Bool = false
}

enum PrivacyScripts {
    static let reportHandler = "aeroReport"

    /// Build the anti-fingerprint / privacy JS for the given config.
    static func buildJS(_ c: PrivacyConfig) -> String {
        guard c.enabled else { return "" }
        func b(_ v: Bool) -> String { v ? "true" : "false" }
        return """
        (function(){
          'use strict';
          try {
            var CFG = {
              canvas: \(b(c.canvasNoise)), webgl: \(b(c.webglSpoof)), audio: \(b(c.audioNoise)),
              fonts: \(b(c.limitFonts)), rects: \(b(c.rectsNoise)), timing: \(b(c.reduceTiming)),
              media: \(b(c.hideMedia)), battery: \(b(c.hideBattery)), sensors: \(b(c.blockSensors)),
              lang: \(b(c.spoofLanguage)), language: "\(c.language)",
              tz: \(b(c.spoofTimezone)), timezone: "\(c.timezone)",
              screen: \(b(c.spoofScreen)),
              geo: \(b(c.spoofGeo)), geoDeny: \(b(c.geoDeny)), lat: \(c.geoLat), lon: \(c.geoLon),
              rtc: \(b(c.blockWebRTC)), nav: \(b(c.hardenNavigator))
            };
            var rnd = function(){ return (Math.random()-0.5)*0.0001; };
            // Deterministic-per-session tiny offset so values are stable within a page but differ across sessions
            var SEED = (Math.random()*1000)|0;
            function defGet(obj, prop, fn){ try { Object.defineProperty(obj, prop, {get: fn, configurable:true}); } catch(e){} }

            // ---- Canvas fingerprint noise ----
            if (CFG.canvas) {
              var origToDataURL = HTMLCanvasElement.prototype.toDataURL;
              HTMLCanvasElement.prototype.toDataURL = function(){
                try { var ctx=this.getContext('2d'); if(ctx){ var w=this.width,h=this.height;
                  if(w&&h){ var img=ctx.getImageData(0,0,w,h);
                    for(var i=0;i<img.data.length;i+=Math.floor(Math.random()*997)+101){ img.data[i]=img.data[i]^1; }
                    ctx.putImageData(img,0,0);} } } catch(e){}
                return origToDataURL.apply(this, arguments);
              };
              var origToBlob = HTMLCanvasElement.prototype.toBlob;
              if (origToBlob) {
                HTMLCanvasElement.prototype.toBlob = function(){
                  try { var ctx=this.getContext('2d'); if(ctx){ var w=this.width,h=this.height;
                    if(w&&h){ var img=ctx.getImageData(0,0,w,h);
                      for(var i=0;i<img.data.length;i+=Math.floor(Math.random()*997)+101){ img.data[i]=img.data[i]^1; }
                      ctx.putImageData(img,0,0);} } } catch(e){}
                  return origToBlob.apply(this, arguments);
                };
              }
              var origGetImageData = CanvasRenderingContext2D.prototype.getImageData;
              CanvasRenderingContext2D.prototype.getImageData = function(){
                var r = origGetImageData.apply(this, arguments);
                try { for(var i=0;i<r.data.length;i+=Math.floor(Math.random()*1500)+251){ r.data[i]=r.data[i]^1; } } catch(e){}
                return r;
              };
              // isPointInPath / measure based readback hardening is covered by fonts block
            }

            // ---- WebGL / WebGL2 / WebGPU spoof ----
            if (CFG.webgl) {
              var spoofParam = function(proto){
                if(!proto) return;
                var orig = proto.getParameter;
                proto.getParameter = function(p){
                  if(p===37445) return 'Apple Inc.';          // UNMASKED_VENDOR_WEBGL
                  if(p===37446) return 'Apple GPU';            // UNMASKED_RENDERER_WEBGL
                  if(p===7936)  return 'WebKit';               // VENDOR
                  if(p===7937)  return 'WebKit WebGL';         // RENDERER
                  return orig.apply(this, arguments);
                };
                var origExt = proto.getExtension;
                proto.getExtension = function(name){
                  if(name==='WEBGL_debug_renderer_info') return null;
                  return origExt.apply(this, arguments);
                };
                var origRead = proto.readPixels;
                if (origRead) {
                  proto.readPixels = function(){
                    var rv = origRead.apply(this, arguments);
                    try { var px=arguments[6]; if(px&&px.length){ for(var i=0;i<px.length;i+=Math.floor(Math.random()*2000)+997){ px[i]=px[i]^1; } } } catch(e){}
                    return rv;
                  };
                }
              };
              if(window.WebGLRenderingContext) spoofParam(WebGLRenderingContext.prototype);
              if(window.WebGL2RenderingContext) spoofParam(WebGL2RenderingContext.prototype);
              try { if (navigator.gpu) { defGet(navigator, 'gpu', function(){ return undefined; }); } } catch(e){}
            }

            // ---- Audio fingerprint noise ----
            if (CFG.audio) {
              if (window.AnalyserNode) {
                var pFFD = AnalyserNode.prototype.getFloatFrequencyData;
                AnalyserNode.prototype.getFloatFrequencyData = function(arr){ pFFD.apply(this, arguments); for(var i=0;i<arr.length;i++){ arr[i]=arr[i]+rnd(); } };
                var pBFD = AnalyserNode.prototype.getByteFrequencyData;
                AnalyserNode.prototype.getByteFrequencyData = function(arr){ pBFD.apply(this, arguments); for(var i=0;i<arr.length;i+=13){ arr[i]=arr[i]^1; } };
                var pFTD = AnalyserNode.prototype.getFloatTimeDomainData;
                if (pFTD) AnalyserNode.prototype.getFloatTimeDomainData = function(arr){ pFTD.apply(this, arguments); for(var i=0;i<arr.length;i++){ arr[i]=arr[i]+rnd(); } };
              }
              if (window.AudioBuffer) {
                var pGCD = AudioBuffer.prototype.getChannelData;
                AudioBuffer.prototype.getChannelData = function(){ var d=pGCD.apply(this, arguments); try { for(var i=0;i<d.length;i+=Math.floor(Math.random()*1000)+500){ d[i]=d[i]+rnd(); } } catch(e){} return d; };
              }
            }

            // ---- Font enumeration limiting ----
            if (CFG.fonts) {
              try {
                if (window.CanvasRenderingContext2D) {
                  var pMeasure = CanvasRenderingContext2D.prototype.measureText;
                  CanvasRenderingContext2D.prototype.measureText = function(){
                    var m = pMeasure.apply(this, arguments);
                    try { var w = m.width; var noisy = w + (((SEED % 7)-3) * 0.00002 * (w||1));
                      return new Proxy(m, { get: function(t,k){ if(k==='width') return noisy; var v=t[k]; return typeof v==='function'?v.bind(t):v; } });
                    } catch(e){ return m; }
                  };
                }
                if (document.fonts && document.fonts.check) {
                  var pCheck = document.fonts.check.bind(document.fonts);
                  document.fonts.check = function(font){
                    try { var allow=/(?:-apple-system|system-ui|Helvetica|Arial|Times|Courier|Georgia|Verdana|sans-serif|serif|monospace)/i;
                      if(!allow.test(font)) return false; } catch(e){}
                    return pCheck.apply(null, arguments);
                  };
                }
              } catch(e){}
            }

            // ---- ClientRects geometry noise ----
            if (CFG.rects) {
              try {
                var jitter = function(v){ return v + (((SEED%5)-2) * 0.00001 * (v||1)); };
                var pBound = Element.prototype.getBoundingClientRect;
                Element.prototype.getBoundingClientRect = function(){
                  var r = pBound.apply(this, arguments);
                  try { return { x:jitter(r.x), y:jitter(r.y), width:jitter(r.width), height:jitter(r.height), top:jitter(r.top), right:jitter(r.right), bottom:jitter(r.bottom), left:jitter(r.left), toJSON:function(){return this;} }; } catch(e){ return r; }
                };
                if (window.Range) {
                  var pRBound = Range.prototype.getBoundingClientRect;
                  Range.prototype.getBoundingClientRect = function(){ var r=pRBound.apply(this, arguments); try { return { x:jitter(r.x), y:jitter(r.y), width:jitter(r.width), height:jitter(r.height), top:jitter(r.top), right:jitter(r.right), bottom:jitter(r.bottom), left:jitter(r.left), toJSON:function(){return this;} }; } catch(e){ return r; } };
                }
              } catch(e){}
            }

            // ---- Timer precision reduction ----
            if (CFG.timing) {
              try {
                if (window.performance && performance.now) {
                  var pNow = performance.now.bind(performance);
                  performance.now = function(){ return Math.floor(pNow()/1.0); };
                }
                var pDateNow = Date.now;
                Date.now = function(){ return Math.floor(pDateNow()/2)*2; };
                if (window.performance) { try { defGet(performance, 'timeOrigin', function(){ return 0; }); } catch(e){} }
              } catch(e){}
            }

            // ---- Media devices hiding ----
            if (CFG.media && navigator.mediaDevices) {
              try {
                navigator.mediaDevices.enumerateDevices = function(){ return Promise.resolve([]); };
                if (navigator.mediaDevices.getDisplayMedia) navigator.mediaDevices.getDisplayMedia = function(){ return Promise.reject(new DOMException('Permission denied','NotAllowedError')); };
              } catch(e){}
            }

            // ---- Battery API hiding ----
            if (CFG.battery) {
              try { if (navigator.getBattery) navigator.getBattery = function(){ return Promise.reject(new DOMException('Not supported','NotSupportedError')); };
                    defGet(navigator, 'battery', function(){ return undefined; }); } catch(e){}
            }

            // ---- Motion / orientation sensors block ----
            if (CFG.sensors) {
              try {
                ['DeviceMotionEvent','DeviceOrientationEvent','Gyroscope','Accelerometer','Magnetometer','AmbientLightSensor','RelativeOrientationSensor','AbsoluteOrientationSensor'].forEach(function(n){ try { window[n]=undefined; } catch(e){} });
                var pAdd = window.addEventListener;
                window.addEventListener = function(type){ if(type==='devicemotion'||type==='deviceorientation'||type==='deviceorientationabsolute'){ return; } return pAdd.apply(this, arguments); };
              } catch(e){}
            }

            // ---- Language ----
            if (CFG.lang) {
              defGet(navigator, 'language', function(){ return CFG.language; });
              defGet(navigator, 'languages', function(){ return [CFG.language, CFG.language.split('-')[0]]; });
            }

            // ---- Timezone ----
            if (CFG.tz) {
              try {
                var DTF = Intl.DateTimeFormat;
                var origRO = DTF.prototype.resolvedOptions;
                DTF.prototype.resolvedOptions = function(){ var o=origRO.apply(this,arguments); o.timeZone=CFG.timezone; return o; };
                Date.prototype.getTimezoneOffset = function(){ return 0; };
              } catch(e){}
            }

            // ---- Screen ----
            if (CFG.screen) {
              defGet(screen, 'width', function(){ return 390; });
              defGet(screen, 'height', function(){ return 844; });
              defGet(screen, 'availWidth', function(){ return 390; });
              defGet(screen, 'availHeight', function(){ return 844; });
              defGet(screen, 'colorDepth', function(){ return 24; });
              defGet(screen, 'pixelDepth', function(){ return 24; });
              defGet(window, 'devicePixelRatio', function(){ return 3; });
              try { if (screen.orientation) defGet(screen.orientation, 'type', function(){ return 'portrait-primary'; }); } catch(e){}
            }

            // ---- Geolocation ----
            if (CFG.geo && navigator.geolocation) {
              var denyErr = { code:1, message:'User denied Geolocation', PERMISSION_DENIED:1, POSITION_UNAVAILABLE:2, TIMEOUT:3 };
              navigator.geolocation.getCurrentPosition = function(ok, err){
                if (CFG.geoDeny) { if(err) err(denyErr); return; }
                if (ok) ok({ coords:{ latitude:CFG.lat, longitude:CFG.lon, accuracy:50, altitude:null, altitudeAccuracy:null, heading:null, speed:null }, timestamp:Date.now() });
              };
              navigator.geolocation.watchPosition = function(ok, err){
                if (CFG.geoDeny) { if(err) err(denyErr); return 0; }
                if (ok) ok({ coords:{ latitude:CFG.lat, longitude:CFG.lon, accuracy:50, altitude:null, altitudeAccuracy:null, heading:null, speed:null }, timestamp:Date.now() });
                return 0;
              };
            }

            // ---- WebRTC IP-leak block ----
            if (CFG.rtc) {
              try {
                var killRTC = function(name){ try { defGet(window, name, function(){ return undefined; }); } catch(e){ try { window[name]=undefined; } catch(e2){} } };
                ['RTCPeerConnection','webkitRTCPeerConnection','mozRTCPeerConnection','RTCDataChannel','RTCIceCandidate','RTCSessionDescription'].forEach(killRTC);
                if (navigator.mediaDevices) navigator.mediaDevices.enumerateDevices = function(){ return Promise.resolve([]); };
              } catch(e){}
            }

            // ---- Navigator hardening ----
            if (CFG.nav) {
              try {
                defGet(navigator, 'webdriver', function(){ return false; });
                defGet(navigator, 'hardwareConcurrency', function(){ return 8; });
                defGet(navigator, 'deviceMemory', function(){ return 8; });
                defGet(navigator, 'maxTouchPoints', function(){ return 5; });
                defGet(navigator, 'vendor', function(){ return 'Apple Computer, Inc.'; });
                defGet(navigator, 'platform', function(){ return 'iPhone'; });
                defGet(navigator, 'productSub', function(){ return '20030107'; });
                defGet(navigator, 'doNotTrack', function(){ return '1'; });
                var emptyPlugins = []; emptyPlugins.item=function(){return null;}; emptyPlugins.namedItem=function(){return null;}; emptyPlugins.refresh=function(){};
                defGet(navigator, 'plugins', function(){ return emptyPlugins; });
                defGet(navigator, 'mimeTypes', function(){ return emptyPlugins; });
                try { if (navigator.userAgentData) defGet(navigator, 'userAgentData', function(){ return undefined; }); } catch(e){}
                try { if (navigator.connection) { defGet(navigator.connection, 'effectiveType', function(){ return '4g'; }); defGet(navigator.connection, 'rtt', function(){ return 50; }); defGet(navigator.connection, 'downlink', function(){ return 10; }); } } catch(e){}
                if (window.Gamepad) { try { navigator.getGamepads = function(){ return []; }; } catch(e){} }
              } catch(e){}
            }
          } catch(e){}
        })();
        """
    }

    /// JS that enters "report ad" picking mode: tap an element → its CSS selector is
    /// posted back to native. A tap highlights + selects the element.
    static var reportPickerJS: String {
        return """
        (function(){
          if (window.__aeroPick) return;
          window.__aeroPick = true;
          // iOS taps don't fire reliable 'click' on plain elements — coax it + use touch.
          try { document.documentElement.style.cursor = 'pointer'; } catch(e){}

          function cssPath(el){
            if(!(el instanceof Element)) return '';
            if(el.id){ return '#'+CSS.escape(el.id); }
            var path=[];
            while(el && el.nodeType===1 && path.length<5){
              var sel=el.nodeName.toLowerCase();
              if(el.classList && el.classList.length){
                var cls=Array.prototype.slice.call(el.classList).filter(function(c){return c.length<30 && !/^[0-9]/.test(c);}).slice(0,2);
                if(cls.length) sel += '.'+cls.map(function(c){return CSS.escape(c);}).join('.');
              } else {
                var p=el.parentNode; if(p){ var i=1,s=el; while((s=s.previousElementSibling)){ if(s.nodeName===el.nodeName) i++; } sel+=':nth-of-type('+i+')'; }
              }
              path.unshift(sel);
              if(el.id) break;
              el=el.parentElement;
            }
            return path.join(' > ');
          }
          function pick(el){
            if(!el || !(el instanceof Element)) return;
            if(el===document.documentElement || el===document.body) return;
            if(window.__aeroLastEl){ try{ window.__aeroLastEl.style.outline=window.__aeroLastEl.__ao||''; }catch(e){} }
            window.__aeroLastEl=el; el.__ao=el.style.outline;
            el.style.setProperty('outline','3px solid #2563EB','important');
            el.style.setProperty('outline-offset','-2px','important');
            var sel=cssPath(el);
            var label=(el.innerText||el.getAttribute&&el.getAttribute('alt')||el.getAttribute&&el.getAttribute('aria-label')||'').replace(/\\s+/g,' ').trim().slice(0,60);
            try { window.webkit.messageHandlers.\(reportHandler).postMessage({selector:sel, host:location.hostname.replace(/^www\\./,''), text:label}); } catch(err){}
          }

          var sx=0, sy=0, moved=false;
          function onStart(e){ var t=(e.touches&&e.touches[0]); if(t){ sx=t.clientX; sy=t.clientY; moved=false; } }
          function onMove(e){ var t=(e.touches&&e.touches[0]); if(t && (Math.abs(t.clientX-sx)>10 || Math.abs(t.clientY-sy)>10)) moved=true; }
          function onEnd(e){
            if(moved) return;                 // a scroll, not a tap
            var t=(e.changedTouches&&e.changedTouches[0]);
            var el = t ? document.elementFromPoint(t.clientX, t.clientY) : null;
            if(!el) return;
            e.preventDefault(); e.stopPropagation();
            pick(el);
          }
          function onClick(e){
            e.preventDefault(); e.stopPropagation();
            pick(e.target);
            return false;
          }

          window.__aeroStart=onStart; window.__aeroMove=onMove; window.__aeroEnd=onEnd; window.__aeroClick=onClick;
          document.addEventListener('touchstart', onStart, true);
          document.addEventListener('touchmove', onMove, true);
          document.addEventListener('touchend', onEnd, true);
          document.addEventListener('click', onClick, true);
        })();
        """
    }

    static var reportExitJS: String {
        return """
        (function(){
          try {
            if(window.__aeroStart){ document.removeEventListener('touchstart', window.__aeroStart, true); }
            if(window.__aeroMove){ document.removeEventListener('touchmove', window.__aeroMove, true); }
            if(window.__aeroEnd){ document.removeEventListener('touchend', window.__aeroEnd, true); }
            if(window.__aeroClick){ document.removeEventListener('click', window.__aeroClick, true); }
            window.__aeroPick=false; window.__aeroStart=null; window.__aeroMove=null; window.__aeroEnd=null; window.__aeroClick=null;
            try { document.documentElement.style.cursor=''; } catch(e){}
            if(window.__aeroLastEl){ try{ window.__aeroLastEl.style.outline=window.__aeroLastEl.__ao||''; }catch(e){} window.__aeroLastEl=null; }
          } catch(e){}
        })();
        """
    }

    /// JS to immediately hide a selector on the current page (after a report is confirmed).
    static func hideSelectorJS(_ selector: String) -> String {
        let esc = selector.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return """
        (function(){
          try {
            var els=document.querySelectorAll("\(esc)");
            for(var i=0;i<els.length;i++){ els[i].style.setProperty('display','none','important'); }
          } catch(e){}
        })();
        """
    }
}
