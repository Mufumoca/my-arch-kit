/* ---------------------------------------------------------------
   Adapted from the original pen's source.js
   (kept verbatim in ./source.pen.js).

   The original used TweenMax 2.x + the *trial* MorphSVGPlugin, whose
   trial build was disabled by GreenSock (it now renders an "Oops! Trial
   version of MorphSVGPlugin deployed" message and stops the page).
   GSAP 3.13+ ships MorphSVGPlugin for free, so this file uses GSAP 3:
     TimelineMax(...)          -> gsap.timeline(...)
     .to(el, 0.3, {...})       -> .to(el, { duration: 0.3, ... })
     Linear.easeNone           -> "none"
     TweenMax.to(...)          -> gsap.to(...)
   --------------------------------------------------------------- */

let main_flame0 = document.getElementById("main-flame_step0"),
    main_flame1 = document.getElementById("main-flame_step1"),
    main_flame2 = document.getElementById("main-flame_step2"),
    main_flame3 = document.getElementById("main-flame_step3"),
    main_flameTIMELINE = gsap.timeline({ repeat: -1, repeatDelay: 0, ease: "none" });

main_flameTIMELINE
  .to(main_flame0, { duration: 0.3, morphSVG: main_flame1, ease: "none" })
  .to(main_flame0, { duration: 0.3, morphSVG: main_flame2, ease: "none" })
  .to(main_flame0, { duration: 0.3, morphSVG: main_flame3, ease: "none" })
  .to(main_flame0, { duration: 0.3, morphSVG: main_flame0, ease: "none" });


let separated_flame0 = document.getElementById("separated-flame_step0"),
    separated_flame1 = document.getElementById("separated-flame_step1"),
    separated_flame2 = document.getElementById("separated-flame_step2"),
    separated_flame3 = document.getElementById("separated-flame_step3"),
    separated_flame4 = document.getElementById("separated-flame_step4"),
    separated_flame5 = document.getElementById("separated-flame_step5"),
    separated_flame6 = document.getElementById("separated-flame_step6"),
    separated_flameTIMELINE = gsap.timeline({ repeat: -1, repeatDelay: 1, ease: "none" });

separated_flameTIMELINE
  .to(separated_flame0, { duration: 0.15, morphSVG: separated_flame1, ease: "none" })
  .to(separated_flame0, { duration: 0.15, morphSVG: separated_flame2, ease: "none" })
  .to(separated_flame0, { duration: 0.3, morphSVG: separated_flame3, ease: "none" })
  .to(separated_flame0, { duration: 0.3, morphSVG: separated_flame4, ease: "none" })
  .to(separated_flame0, { duration: 0.1, morphSVG: separated_flame5, ease: "none" })
  .to(separated_flame0, { duration: 0.15, morphSVG: separated_flame6, ease: "none" });

// Little tomato circle following the flame outline
var path = MorphSVGPlugin.pathDataToBezier(main_flame0);
gsap.to("#circle", {
  duration: 5,
  bezier: { values: path, type: "cubic" },
  ease: "none",
  repeat: -1
});
