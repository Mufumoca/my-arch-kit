pragma ComponentBehavior: Bound

import QtQuick
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// 天气页：左边一颗大爆炸星托着天气图标 + 巨大的 Anton 温度；右上一排歪斜的情报牌（湿度 / 风 / 气压 / 降水 / 日出日落）；
// 底部是一列错落的预报卡片，DAILY / HOURLY 切换。
Item {
    id: root

    property bool live: false

    implicitWidth: 880
    implicitHeight: 420

    readonly property var w: WeatherService.weather
    readonly property bool available: !!w.available
    readonly property bool fahrenheit: SettingsData.useFahrenheit
    property bool hourly: false

    property bool weatherRefHeld: false
    function syncWeatherRef(wanted) {
        if (wanted === weatherRefHeld)
            return;
        weatherRefHeld = wanted;
        if (wanted)
            WeatherService.addRef();
        else
            WeatherService.removeRef();
    }
    onLiveChanged: syncWeatherRef(live)
    Component.onCompleted: syncWeatherRef(live)
    Component.onDestruction: syncWeatherRef(false)

    function deg(c, f) {
        return (fahrenheit ? f : c) + "°";
    }

    // 预报卡片的数据：每日 7 张，或从当前小时起每 2 小时一张
    readonly property var cards: {
        if (!available)
            return [];
        if (!hourly)
            return (w.forecast || []).slice(0, 7).map((d, i) => ({
                        "label": d.day,
                        "icon": WeatherService.getWeatherIcon(d.wCode, true),
                        "hi": deg(d.tempMax, d.tempMaxF),
                        "lo": deg(d.tempMin, d.tempMinF),
                        "rain": d.precipitationProbability || 0,
                        "now": i === 0
                    }));
        const list = w.hourlyForecast || [];
        const now = new Date();
        let start = list.findIndex(h => new Date(h.rawTime) >= new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours()));
        if (start < 0)
            start = 0;
        const out = [];
        for (let i = start; i < list.length && out.length < 7; i += 2) {
            const h = list[i];
            out.push({
                "label": h.time,
                "icon": WeatherService.getWeatherIcon(h.wCode, h.isDay),
                "hi": deg(h.temp, h.tempF),
                "lo": "",
                "rain": h.precipitationProbability || 0,
                "now": i === start
            });
        }
        return out;
    }

    function handleKeyEvent(event) {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_H && !(event.modifiers & Qt.ControlModifier)) {
            hourly = !hourly;
            return true;
        }
        if (event.key === Qt.Key_R) {
            WeatherService.forceRefresh();
            return true;
        }
        return false;
    }

    // 背景大字
    Text {
        x: root.width - 470
        y: -26
        text: "FORECAST"
        color: P5.alpha(P5.violet, 0.07)
        font.family: P5.displayFont
        font.pixelSize: 124
        rotation: -6
    }

    // ---- 没有数据 ----
    Item {
        anchors.fill: parent
        visible: !root.available

        P5Burst {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            width: 220
            height: 220
            spikes: 12
            depth: 0.34
            seed: 41
            fillColor: P5.ink
            strokeColor: P5.violet
            strokeWidth: 3
            slabColor: P5.alpha(P5.pink, 0.6)
            slabOffset: Qt.point(8, 8)
        }
        DankIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            name: WeatherService.weather.loading ? "cloud_sync" : "cloud_off"
            size: 72
            color: P5.violet
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 + 90
            spacing: 8
            P5Tag {
                anchors.horizontalCenter: parent.horizontalCenter
                text: WeatherService.weather.loading ? "GATHERING INTEL…" : "NO INTEL"
                family: P5.displayFont
                italic: false
                weight: Font.Normal
                pixelSize: 22
                fillColor: P5.paper
                textColor: P5.ink
                slabColor: P5.violet
                tilt: -3
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text.length > 0
                width: Math.min(implicitWidth, root.width - 120)
                elide: Text.ElideRight
                text: WeatherService.lastFetchError
                color: P5.lilac
                font.pixelSize: 12
            }
        }
    }

    // ---- 当前天气 ----
    Item {
        id: hero
        visible: root.available
        x: 18
        y: 14
        width: 360
        height: 250

        P5Burst {
            x: -10
            y: 6
            width: 210
            height: 210
            spikes: 14
            depth: 0.3
            seed: 43
            fillColor: P5.violet
            strokeColor: P5.paper
            strokeWidth: 3
            slabColor: P5.ink
            slabOffset: Qt.point(9, 9)
            NumberAnimation on spin {
                from: 0
                to: 360
                duration: 60000
                loops: Animation.Infinite
                running: root.live && P5.motionEnabled
            }
        }
        DankIcon {
            x: 95 - size / 2 - 10
            y: 111 - size / 2
            name: WeatherService.getWeatherIcon(root.w.wCode)
            size: 96
            color: P5.ink
            rotation: -6
        }

        // 温度：描边大字 + 淡紫错位
        Item {
            x: 178
            y: 4
            width: tempText.implicitWidth
            height: tempText.implicitHeight
            rotation: -4

            Text {
                x: 7
                y: 7
                text: tempText.text
                font: tempText.font
                color: P5.pink
            }
            Text {
                id: tempText
                text: root.deg(root.w.temp, root.w.tempF)
                color: P5.paper
                style: Text.Outline
                styleColor: P5.ink
                font.family: P5.displayFont
                font.pixelSize: 118
            }
        }

        P5Tag {
            x: 190
            y: 160
            text: WeatherService.getWeatherCondition(root.w.wCode)
            family: P5.bodyFont
            italic: false
            weight: Font.Black
            pixelSize: 17
            fillColor: P5.paper
            textColor: P5.ink
            slabColor: P5.violet
            slabOffset: Qt.point(4, 4)
            tilt: 3
        }
        P5Tag {
            x: 202
            y: 198
            text: "FEELS " + root.deg(root.w.feelsLike, root.w.feelsLikeF)
            pixelSize: 13
            fillColor: P5.ink
            textColor: P5.lilac
            borderWidth: 1.5
            borderColor: P5.lilac
            tilt: -2
        }

        // 地点
        Row {
            x: 6
            y: 222
            spacing: 6
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "location_on"
                size: 18
                color: P5.pink
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.w.city || "").toUpperCase() + (root.w.country && root.w.country !== I18n.tr("Unknown") ? "  /  " + root.w.country.toUpperCase() : "")
                color: P5.paper
                font.family: P5.labelFont
                font.pixelSize: 16
                font.italic: true
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
        }
    }

    // ---- 情报牌 ----
    Grid {
        id: intel
        visible: root.available
        x: hero.x + hero.width + 30
        y: 24
        columns: 3
        columnSpacing: 12
        rowSpacing: 14

        component Intel: Item {
            id: card
            property string icon
            property string label
            property string value
            property int n: 0
            width: 146
            height: 72
            rotation: n % 2 === 0 ? -2 : 1.5

            P5Plate {
                anchors.fill: parent
                skew: 14
                jitter: 2.5
                seed: 50 + card.n
                fillColor: P5.inkRaised
                borderWidth: 2
                borderColor: P5.paper
                slabColor: card.n === 0 ? P5.pink : P5.violet
                slabOffset: Qt.point(5, 5)
            }
            P5Tag {
                x: 10
                y: -8
                text: card.label
                pixelSize: 11
                fillColor: P5.violet
                textColor: P5.ink
                tilt: -4
            }
            DankIcon {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 6
                name: card.icon
                size: 22
                color: P5.violet
            }
            Text {
                x: 46
                width: parent.width - 54
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 6
                text: card.value
                color: P5.paper
                font.family: P5.displayFont
                font.pixelSize: 21
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 12
            }
        }

        Intel {
            n: 0
            icon: "humidity_percentage"
            label: "HUMIDITY"
            value: WeatherService.formatPercent(root.w.humidity) ?? "--"
        }
        Intel {
            n: 1
            icon: "air"
            label: "WIND"
            value: WeatherService.formatSpeed(root.w.wind) ?? "--"
        }
        Intel {
            n: 2
            icon: "rainy"
            label: "RAIN"
            value: (root.w.precipitationProbability ?? 0) + "%"
        }
        Intel {
            n: 3
            icon: "compress"
            label: "PRESSURE"
            value: WeatherService.formatPressure(root.w.pressure) ?? "--"
        }
        Intel {
            n: 4
            icon: "wb_twilight"
            label: "SUNRISE"
            value: root.w.sunrise || "--"
        }
        Intel {
            n: 5
            icon: "bedtime"
            label: "SUNSET"
            value: root.w.sunset || "--"
        }
    }

    // ---- 预报 ----
    Item {
        id: forecast
        visible: root.available
        x: 14
        y: root.height - 146
        width: root.width - 28
        height: 140

        // 斜切分隔带
        P5Poly {
            x: -14
            y: -8
            width: root.width
            height: 4
            points: [[0, 6], [root.width, -4], [root.width, 0], [0, 10]]
            fillColor: P5.paper
        }

        // 切换 + 刷新
        Row {
            x: 4
            y: 4
            spacing: 6
            Repeater {
                model: ["DAILY", "HOURLY"]
                P5Tag {
                    id: tab
                    required property string modelData
                    required property int index
                    readonly property bool on: root.hourly === (index === 1)
                    text: modelData
                    family: P5.displayFont
                    italic: false
                    weight: Font.Normal
                    pixelSize: 14
                    fillColor: on ? P5.violet : P5.ink
                    textColor: on ? P5.ink : P5.lilac
                    borderWidth: on ? 0 : 1.5
                    borderColor: P5.lilac
                    tilt: -4
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.hourly = tab.index === 1
                    }
                }
            }
        }
        P5ActionChip {
            anchors.right: parent.right
            y: 2
            icon: "refresh"
            hint: "REFRESH"
            onActivated: WeatherService.forceRefresh()
        }

        Row {
            y: 34
            spacing: 10
            Repeater {
                model: root.cards
                Item {
                    id: fc
                    required property var modelData
                    required property int index
                    width: (forecast.width - 60) / 7
                    height: 100
                    rotation: index % 2 === 0 ? -2.5 : 2
                    y: index % 2 === 0 ? 0 : 6

                    P5Plate {
                        anchors.fill: parent
                        skew: 12
                        jitter: 2
                        seed: 70 + fc.index
                        fillColor: fc.modelData.now ? P5.violet : P5.ink
                        borderWidth: fc.modelData.now ? 0 : 1.5
                        borderColor: P5.lilac
                        slabColor: fc.modelData.now ? P5.ink : "transparent"
                        slabOffset: Qt.point(5, 5)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 6
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: String(fc.modelData.label).toUpperCase()
                        color: fc.modelData.now ? P5.ink : P5.lilac
                        font.family: P5.labelFont
                        font.pixelSize: 13
                        font.italic: true
                        font.weight: Font.Bold
                    }
                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 26
                        name: fc.modelData.icon
                        size: 28
                        color: fc.modelData.now ? P5.ink : P5.paper
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 58
                        spacing: 5
                        Text {
                            text: fc.modelData.hi
                            color: fc.modelData.now ? P5.ink : P5.paper
                            font.family: P5.displayFont
                            font.pixelSize: 18
                        }
                        Text {
                            visible: fc.modelData.lo !== ""
                            text: fc.modelData.lo
                            color: fc.modelData.now ? P5.velvet : P5.lilac
                            font.family: P5.displayFont
                            font.pixelSize: 13
                        }
                    }
                    // 降水概率：底部一条细拉力条
                    P5Meter {
                        x: 12
                        y: parent.height - 15
                        width: parent.width - 24
                        height: 7
                        ticks: 0
                        value: fc.modelData.rain / 100
                        fillColor: fc.modelData.now ? P5.ink : P5.pink
                        trackColor: fc.modelData.now ? P5.alpha(P5.ink, 0.25) : P5.inkRaised
                        borderColor: "transparent"
                    }
                }
            }
        }
    }
}
