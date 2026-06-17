import Foundation

/// Configuration snapshot used to build the privacy JS injected at document start.
struct PrivacyConfig {
    var enabled: Bool = false           // master privacy switch (or incognito)
    var canvasNoise: Bool = false
    var webglSpoof: Bool = false
    var audioNoise: Bool = false
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
              lang: \(b(c.spoofLanguage)), language: "\(c.language)",
              tz: \(b(c.spoofTimezone)), timezone: "\(c.timezone)",
              screen: \(b(c.spoofScreen)),
              geo: \(b(c.spoofGeo)), geoDeny: \(b(c.geoDeny)), lat: \(c.geoLat), lon: \(c.geoLon),
              rtc: \(b(c.blockWebRTC)), nav: \(b(c.hardenNavigator))
            };
            var rnd = function(){ return (Math.random()-0.5)*0.0001; };

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
              var origGetImageData = CanvasRenderingContext2D.prototype.getImageData;
              CanvasRenderingContext2D.prototype.getImageData = function(){
                var r = origGetImageData.apply(this, arguments);
                try { for(var i=0;i<r.data.length;i+=Math.floor(Math.random()*1500)+251){ r.data[i]=r.data[i]^1; } } catch(e){}
                return r;
              };
            }

            // ---- WebGL spoof ----
            if (CFG.webgl) {
              var spoofParam = function(proto){
                if(!proto) return;
                var orig = proto.getParameter;
                proto.getParameter = function(p){
                  if(p===37445) return 'Apple Inc.';        // UNMASKED_VENDOR_WEBGL
                  if(p===37446) return 'Apple GPU';          // UNMASKED_RENDERER_WEBGL
                  return orig.apply(this, arguments);
                };
              };
              if(window.WebGLRenderingContext) spoofParam(WebGLRenderingContext.prototype);
              if(window.WebGL2RenderingContext) spoofParam(WebGL2RenderingContext.prototype);
            }

            // ---- Audio fingerprint noise ----
            if (CFG.audio && window.AnalyserNode) {
              var origFFD = AnalyserNode.prototype.getFloatFrequencyData;
              AnalyserNode.prototype.getFloatFrequencyData = function(arr){
                origFFD.apply(this, arguments);
                for(var i=0;i<arr.length;i++){ arr[i]=arr[i]+rnd(); }
              };
            }

            // ---- Language ----
            if (CFG.lang) {
              try { Object.defineProperty(navigator,'language',{get:function(){return CFG.language;}}); } catch(e){}
              try { Object.defineProperty(navigator,'languages',{get:function(){return [CFG.language, CFG.language.split('-')[0]];}}); } catch(e){}
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
              try {
                Object.defineProperty(screen,'width',{get:function(){return 390;}});
                Object.defineProperty(screen,'height',{get:function(){return 844;}});
                Object.defineProperty(screen,'availWidth',{get:function(){return 390;}});
                Object.defineProperty(screen,'availHeight',{get:function(){return 844;}});
                Object.defineProperty(window,'devicePixelRatio',{get:function(){return 3;}});
              } catch(e){}
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
                window.RTCPeerConnection = undefined;
                window.webkitRTCPeerConnection = undefined;
                window.RTCDataChannel = undefined;
                if (navigator.mediaDevices) navigator.mediaDevices.enumerateDevices = function(){ return Promise.resolve([]); };
              } catch(e){}
            }

            // ---- Navigator hardening ----
            if (CFG.nav) {
              try {
                Object.defineProperty(navigator,'webdriver',{get:function(){return false;}});
                Object.defineProperty(navigator,'hardwareConcurrency',{get:function(){return 8;}});
                Object.defineProperty(navigator,'deviceMemory',{get:function(){return 8;}});
                Object.defineProperty(navigator,'plugins',{get:function(){return [];}});
                Object.defineProperty(navigator,'maxTouchPoints',{get:function(){return 5;}});
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
          var last;
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
          function onTap(e){
            var el=e.target; if(!el) return;
            e.preventDefault(); e.stopPropagation();
            if(last){ last.style.outline=last.__ao||''; }
            last=el; el.__ao=el.style.outline; el.style.outline='3px solid #2563EB';
            el.style.outlineOffset='-3px';
            var sel=cssPath(el);
            try { window.webkit.messageHandlers.\(reportHandler).postMessage({selector:sel, host:location.hostname.replace(/^www\\./,''), text:(el.innerText||'').slice(0,60)}); } catch(err){}
            return false;
          }
          window.__aeroTap = onTap;
          document.addEventListener('click', onTap, true);
        })();
        """
    }

    static var reportExitJS: String {
        return """
        (function(){
          try {
            if(window.__aeroTap){ document.removeEventListener('click', window.__aeroTap, true); }
            window.__aeroPick=false; window.__aeroTap=null;
            if(window.__aeroLastEl){ window.__aeroLastEl.style.outline=''; }
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
