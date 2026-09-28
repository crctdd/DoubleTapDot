# 双击圆点 / DoubleTapDot

Package: `com.crctdd.doubletapdot`

Version: `0.0.1`

## 第一版功能

- SpringBoard 全局悬浮半透明蓝点。
- 单击蓝点一次，在蓝点圆心位置模拟双击。
- 双击间隔可设置为 1–300 ms，保存时按 1 ms 取整。
- 长按蓝点 1 秒后进入拖动。
- 松手立即保存蓝点位置。
- 注销、重新加载 SpringBoard、重启后会恢复上次位置。
- 圆点大小可设置为 20–100 pt。
- 设置页总开关。
- 设置页可重置蓝点位置。
- GitHub Actions 同时构建 rootless / roothide。

## 默认值

- 启用：是
- 圆点大小：44 pt
- 双击间隔：30 ms
- 长按拖动时间：1 秒（固定）
- 默认位置：屏幕右侧中间

## 构建

标准 Theos：

```sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

RootHide：

```sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

也可以直接推送到 GitHub，然后在 Actions 中运行 `Build DoubleTapDot`。

## 实现说明

蓝点位置保存为屏幕宽高的归一化比例，而不是固定像素。双击使用 IOHID digitizer 事件发送到系统触摸栈。注入期间蓝点会短暂进入穿透状态，避免合成触摸再次点到蓝点自身。

这是第一版工程，优先验证 iOS 16/17 的 SpringBoard 全局悬浮与双击识别稳定性。
