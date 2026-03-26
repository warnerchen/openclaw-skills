---
name: suse_support_case_search_queue
description: Navigate to a Salesforce Case list page using a filterName.
---

## When to use

当用户希望：

- 查看某个队列
- 查看某个 Case 列表
- 进入指定 filterName 的 Case 页面

时使用本 Skill。

---

## SUSE Support Queue 导航方法

注意：严格按照本流程一步步执行。

使用用户提供的 filterName，在 Salesforce 中按以下流程操作：

1. 使用 filterName 进行 URL 拼接：https://suse.lightning.force.com/lightning/o/Case/list?filterName=<filterName>

2. 使用 Agent Browsers 访问该 URL：

```bash
agent-browser open https://suse.lightning.force.com/lightning/o/Case/list?filterName=<filterName> && agent-browser wait --load networkidle
```

3. 等待页面加载完成，查看是否有 Ref：

```bash
agent-browser snapshot -i
```

如果用户没有提供 filterName，返回以下常用 filterName 给用户选择：

1. MyOpenCases(我的未处理个案)
2. Rancher_Priority_Queue_GC_Only(GC Native Cloud Support Team 的未接受个案)
3. Support_Team1(GC Native Cloud Support Team 的未处理个案)
4. Warner_Chen(Warner Chen 的未处理个案)

---

## 成功判定

满足以下条件之一，则认为操作成功：

- 页面显示 Case 列表（包含 Case 表格）或显示 “此处无任何内容”、“Nothing to see here”

---

### 输出格式

如果有 Case，按以下格式输出信息：

| Case | 优先级 | 联系人姓名 | 主题 | 子态 | 所有人姓名 | 开始时间 |
|------|-------|----------|------|-----|----------|---------|
| <CASE_ID> | <Priority> | <Contect Name> | <Subject> | <Sub Status> | <Case Owner> | <Date/Time Opened> |

---

### 输出规则

- 如果列表中没有子态，则获取 “状态” 的内容填入

如果没有 Case，返回：目前该队列没有 Case

---

## 失败判定

出现以下情况，则认为操作失败：

- agent-browser 执行报错
- Salesforce 需要进行登陆
- 页面显示 The requested resource does not exist

### 失败处理

如果操作判定为失败，返回具体失败原因。
