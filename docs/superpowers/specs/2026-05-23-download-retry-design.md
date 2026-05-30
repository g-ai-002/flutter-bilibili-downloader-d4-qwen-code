# 下载失败重试功能设计

## 背景

当前下载任务失败后会进入 `failed` 状态并保存错误信息。用户只能删除任务后重新添加，批量下载时遇到临时网络波动、源站限流或 Bilibili 分片失败会中断单个任务，后续处理成本较高。

## 目标

下载失败后自动重试最多 3 次；如果仍然失败，任务保留在列表中并提供手动“重试”按钮。

## 非目标

- 不增加系统设置项配置重试次数。
- 不做指数退避、定时延迟重试或后台调度器。
- 不改变现有并发数、队列顺序和下载格式选择逻辑。

## 后端设计

### 任务模型

`DownloadJob` 增加字段：

- `retry_count: int = 0`：当前任务已经自动重试的次数。
- `max_retries: int = 3`：自动重试上限。

`to_dict()` 和 `from_dict()` 持久化这两个字段，保证服务重启后任务列表仍能展示重试状态。

### 自动重试

`JobManager._run_one()` 捕获下载异常时不立即永久失败：

1. 如果异常是 `FileNotFoundError`，仍然直接失败，因为缺少 ffmpeg 不是临时错误。
2. 对其他异常：
   - 当 `retry_count < max_retries` 时：
     - `retry_count += 1`
     - `status = queued`
     - `error = repr(exc)`
     - 重置本次下载进度字段
     - 保存任务
     - 重新放回队列
   - 当 `retry_count >= max_retries` 时：
     - `status = failed`
     - `error = repr(exc)`
     - `finished_at = time.time()`
     - 保存任务

这样临时网络失败会自动继续尝试，永久失败不会无限占用队列。

### 手动重试接口

新增 `JobManager.retry(job_id: int) -> bool`：

- 只允许 `failed` 或 `canceled` 状态。
- 将任务状态改为 `queued`。
- 清空 `error`。
- 重置 `retry_count = 0`、进度、速度、开始/结束时间。
- 将任务重新放入队列并保存。

新增接口：

`POST /api/jobs/{job_id}/retry`

成功返回：

```json
{"id": 1, "status": "queued"}
```

不允许重试时返回 400，任务不存在时返回 404。

## 前端设计

任务列表读取 `retry_count` 和 `max_retries`：

- `downloading` 状态下，如果 `retry_count > 0`，显示“第 N 次重试”。
- `failed` 状态下显示“失败 · 已重试 N/M 次”。
- `failed` 或 `canceled` 状态显示“重试”按钮。
- 点击“重试”调用 `POST /api/jobs/{id}/retry`，成功后刷新任务列表。

## 测试设计

新增/更新后端测试：

1. 下载第一次失败、第二次成功时，任务最终 `completed`，`retry_count == 1`。
2. 下载连续失败超过 3 次后，任务最终 `failed`，错误信息保留。
3. 手动重试 `failed` 任务后，任务回到 `queued`，错误和进度被清空。
4. 不允许重试正在下载或已完成的任务。

前端验证：

- `node --check ovd/static/index.html` 验证脚本语法。
- 通过浏览器或接口确认失败任务显示“重试”按钮。

## 验收标准

- 临时失败任务可自动重试最多 3 次。
- 自动重试耗尽后任务保留为失败状态并展示错误。
- 用户可以在页面手动重试失败任务。
- 任务重试状态可持久化，服务重启后不丢失。
- `pytest -v` 全部通过。
