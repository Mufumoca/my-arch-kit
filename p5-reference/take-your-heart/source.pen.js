let main_flame0 = document.getElementById("main-flame_step0"),
    main_flame1 = document.getElementById("main-flame_step1"),
    main_flame2 = document.getElementById("main-flame_step2"),
    main_flame3 = document.getElementById("main-flame_step3"),
    main_flameTIMELINE = new TimelineMax({repeat:-1, repeatDelay:0, ease:Linear.easeNone});
main_flameTIMELINE
.to(main_flame0, 0.3, { morphSVG: main_flame1, ease:Linear.easeNone })
.to(main_flame0, 0.3, { morphSVG: main_flame2, ease:Linear.easeNone })
.to(main_flame0, 0.3, { morphSVG: main_flame3, ease:Linear.easeNone })
.to(main_flame0, 0.3, { morphSVG: main_flame0, ease:Linear.easeNone });


let separated_flame0 = document.getElementById("separated-flame_step0"),
    separated_flame1 = document.getElementById("separated-flame_step1"),
    separated_flame2 = document.getElementById("separated-flame_step2"),
    separated_flame3 = document.getElementById("separated-flame_step3"),
    separated_flame4 = document.getElementById("separated-flame_step4"),
    separated_flame5 = document.getElementById("separated-flame_step5"),
    separated_flame6 = document.getElementById("separated-flame_step6"),
    separated_flameTIMELINE = new TimelineMax({repeat:-1, repeatDelay:1, ease:Linear.easeNone});
separated_flameTIMELINE
.to(separated_flame0, 0.15, { morphSVG: separated_flame1, ease:Linear.easeNone })
.to(separated_flame0, 0.15, { morphSVG: separated_flame2, ease:Linear.easeNone })
.to(separated_flame0, 0.3, { morphSVG: separated_flame3, ease:Linear.easeNone })
.to(separated_flame0, 0.3, { morphSVG: separated_flame4, ease:Linear.easeNone })
.to(separated_flame0, 0.1, { morphSVG: separated_flame5, ease:Linear.easeNone })
.to(separated_flame0, 0.15, { morphSVG: separated_flame6, ease:Linear.easeNone });

// Example:
var path = MorphSVGPlugin.pathDataToBezier(main_flame0);
TweenMax.to("#circle", 5, {bezier:{values:path, type:"cubic"}, ease:Linear.easeNone, repeat:-1});

// Make one/two paths that map to mid points of the different stages of the main flame animation. (NO LOOP)
// Animate on these

//WHich means I first need to perfect the main animation loop