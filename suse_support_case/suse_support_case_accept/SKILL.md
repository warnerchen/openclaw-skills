---
name: suse_support_case_accept
description: Accept a Salesforce case using a Case ID.
---

## When to use

当用户希望接受某个尚未被处理的 Case 时使用本 Skill。

---

## SUSE Support Case 接受方法

注意：严格按照本流程一步步执行。

使用用户提供的 Case 编号（<CASE_ID>），按以下流程操作：

---

1. 打开 Case 页面

- 调用 Skill `suse_support_case_view`
- 进入 `<CASE_ID>` 对应的 Case 详情页面

2. 检查 Case 状态

在执行接受操作前，确认：

- 当前 Case 处于可接受状态（Case Owner 不为 Global Rancher）
- 页面存在 “接受”、“Accept” 按钮

如果不满足上述条件，则终止操作。

3. 接受 Case

找到 “接受”、“Accept” 按钮并点击：

```bash
# 确认 “接受”、“Accept” 的实际 Ref，一般情况下为 e59
agent-browser snapshot -i | grep -Ei '接受|Accept'
agent-browser click e59 && agent-browser wait --load networkidle
```

---

## 成功判定

满足以下全部条件，则认为操作成功：

- 点击 “接受”、“Accept” 后页面成功响应（无报错）
- Case Owner 已变更为当前用户
- 页面不再显示 “接受”、“Accept” 按钮

---

## 失败判定

出现以下任一情况，则认为操作失败：

- 页面不存在 “接受”、“Accept” 按钮
- Case Owner 不为 Global Rancher
- 点击后无响应或操作失败
- Case Owner 未发生变化

---

### 失败处理

如果操作判定为失败，返回具体失败原因。
