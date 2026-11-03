# ActionReClientDemo

行为识别可视化系统的客户端原型（PyQt5 桌面应用）。

项目采用 MVC 结构，把界面展示、控制逻辑和数据存储分开，并通过 PyQt5 的信号与槽在模块之间通信。当前实现了一个最小可运行的图片序列播放器：定时从本地数据中读取图片帧，解码后在窗口中逐帧显示。本仓库只包含客户端展示逻辑，不包含行为识别模型。

> 项目目前处于原型阶段：姿态骨架绘制、多人信息面板等代码已经存在，但尚未接入主播放流程。

## 功能现状

- 以 25 ms 的间隔逐帧播放本地图片序列
- 使用 OpenCV 解码图片，并通过 PyQt5 的 `QLabel` 显示
- 提供 OpenPose 关节点/骨架绘制工具（`Visualization.py`）
- 提供多人信息卡片控件（`wind.py`，尚未接入主界面）

## 目录结构

| 文件 | 说明 |
| --- | --- |
| `main.py` | 程序入口，定义 View（`ActionRe`），创建 Model 和 Controller 并连接信号 |
| `controller.py` | Controller：定时驱动取数、解码图片、把结果写入 Model |
| `model.py` | Model：持有当前帧数据，更新后发出 `dataChangedSignal` |
| `utils.py` | 数据读取：本地图片序列 / 远程示例图，以及姿态 `.npy` 的加载 |
| `Visualization.py` | 基于 OpenCV 的 OpenPose 骨架绘制工具 |
| `TonCV2.py` | OpenCV 的 RGB 读写小封装 |
| `wind.py` | 多人信息展示控件（实验性，未接入） |
| `data/` | 本地数据目录，未纳入版本库 |
| `start.sh` | 应用启动脚本（后台运行，见“运行”） |
| `stop.sh` | 应用停止脚本（见“运行”） |
| `.idea/` | PyCharm 工程配置 |

## 架构说明

### MVC 模式

- **View**（`main.py` 中的 `ActionRe`）：只负责从 Model 取数据并更新界面。
- **Model**（`model.py`）：只负责存放数据，目前不涉及数据的增删改。
- **Controller**（`controller.py`）：控制所有逻辑，例如播放定时、原始数据解码与处理。

数据流：

```text
View (ActionRe)
  │ initOkSignal
  ▼
Controller.route → startTimer
  │ QBasicTimer（25 ms）
  ▼
utils.get_data() → processData() → Model.setData()
                                      │ dataChangedSignal
                                      ▼
                              View.getData() → updataUI()
```

1. 主程序在界面显示前通过 `initOkSignal` 通知 Controller 启动定时器。
2. Controller 的 `QBasicTimer` 每 25 ms 触发一次 `timerEvent`。
3. `timerEvent` 调用 `utils.get_data()` 取得下一帧数据，经 `processData()` 解码后写入 Model。
4. Model 发出 `dataChangedSignal`，View 取回数据并刷新界面。

### 信号与槽

模块间通信依赖 PyQt5 的 signal/slot，目前有两对：

- `ActionRe.initOkSignal` → `Controller.route`：通知 Controller 开启计时器。
- `Model.dataChangedSignal` → `ActionRe.getData`：Model 数据更新后通知 View 刷新。

## 运行环境

- Python 3.8–3.11（项目最初基于 Python 3.6）
- 依赖：PyQt5、numpy、opencv-python、requests、Pillow（需 `<10`，原因见“已知限制”）

仓库没有提供 `requirements.txt`，可以手动安装：

```bash
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install PyQt5 numpy opencv-python requests "Pillow<10"
```

## 数据准备

`data/` 已在 `.gitignore` 中忽略，克隆仓库后需要自行准备数据：

```text
data/
├── 20.npy
└── 20_imga/
    ├── 000001.jpg
    └── ...
```

- `data/20_imga/`：按帧排列的图片文件。
- `data/20.npy`：姿态数据。代码按 `poses[0, :2, 帧序号, :]` 取值，再转置为 `(关键点数, 2)` 的坐标数组，因此需要能按该方式索引；图片数量应与姿态帧数一致。
- 图片按 `os.listdir()` 的顺序读取，建议文件名使用补零的序号，保证顺序稳定。
- 根目录的 `1.npy` 仅用于 `utils.get_data()` 中的远程示例逻辑和 `Visualization.py` 的演示入口，默认播放流程不会用到。

## 运行

在项目根目录执行（相对路径基于当前工作目录）：

```bash
python main.py
```

程序会打开一个 1120×630 的窗口，在左上角 960×540 的区域中逐帧显示图片。

### 使用脚本启动和停止

macOS / Linux 下可以使用仓库根目录的脚本在后台启动和停止应用：

```bash
./start.sh   # 后台启动应用
./stop.sh    # 停止应用
```

- `start.sh` 默认优先使用项目根目录下的 `.venv/bin/python`，其次使用 PATH 中的 `python3`；也可以通过 `PYTHON_BIN=/path/to/python ./start.sh` 指定解释器。
- 应用在后台运行，PID 写入 `.run/app.pid`，输出写入 `.run/app.log`；`.run/` 已被 `.gitignore` 忽略。
- 启动后如果进程立即退出（例如缺少依赖、没有图形环境或 `data/` 未准备），脚本会打印日志末尾并以非零状态退出。
- `stop.sh` 先发送 SIGTERM；若 `STOP_TIMEOUT` 秒（默认 10 秒）后仍未退出，则发送 SIGKILL 强制结束。

Windows 下请直接运行 `python main.py`。

## 已知限制

- 主播放流程目前只显示原图，尚未把 `Visualization.render()` 绘制的姿态骨架叠加到画面上；`boundingBox`、`nameAndAction` 字段虽在数据中保留，也未在界面展示。
- `wind.py` 中的多人信息控件尚未接入主界面。
- 图片播放到末尾后 `get_data()` 返回 `None`，`Controller.processData()` 未处理空值，程序会因异常中断；暂不支持循环播放或进度控制。
- `utils.get_data` 在模块末尾被覆盖为本地读取函数，原有的远程示例读取逻辑默认不会执行。
- `Visualization.py` 中保留了作者本机的 Windows 路径和调试输出。
- 帧转 `QPixmap` 依赖 `PIL.Image.toqpixmap()`；Pillow 10.0 起移除了 `ImageQt` 对 PyQt5 的支持，新版 Pillow 会抛出 `ImportError: Qt bindings are not installed`，因此需要安装 `Pillow<10`。
- 项目暂无自动化测试和 CI。
