---
name: suse_support_case_view
description: Navigate to and open a specific Salesforce case page using a Case ID.
---

## When to use

当用户提供 Case 编号，并希望查看或进入某个 Case 页面时使用本 Skill。

---

## SUSE Support Case 导航方法

注意：严格按照本流程一步步执行。

使用用户提供的 Case 编号（<CASE_ID>），在 Salesforce 中按以下流程操作：

1. 进入 All Cases 队列：

```bash
agent-browser open https://suse.lightning.force.com/lightning/o/Case/list?filterName=All_cases && agent-browser wait --load networkidle
```

2. 等待页面加载完成，查看是否有 Ref：

```bash
agent-browser snapshot -i
```

3. 通过 Case 编号进行查询

```bash
# 确认 “搜索此列表”、“Search this list” 的实际 Ref
agent-browser snapshot -i | grep -Ei '搜索此列表|Search this list'
agent-browser fill @exxx "<CASE_ID>"
```

3. 模拟点击 Enter

```bash
agent-browser press "Enter"
```

4. 进入 Case

```bash
# 确认 Case 的实际跳转 Ref
agent-browser snapshot -i | grep "<CASE_ID>" | grep link
agent-browser click @exxx && agent-browser wait --load networkidle
```

5. 等待页面加载完成，查看是否有 Ref：

```bash
agent-browser snapshot -i
```

---

## 成功判定

满足以下全部条件，则认为操作成功：

- 成功进入 Case 详情页
- 使用 `agent-browser get title` 获取当前页面 Case 编号，需要与搜索编号相同

---

### 输出格式

成功后进入 Case 详情页，按以下格式输出信息（未获取到的字段标记为“未知”）：

**基本信息：**
- **Case**：<CASE_ID>
- **主题**：<Subject>
- **产品**：<Product>
- **优先级**：<Priority>
- **状态**：<Status>
- **子态**：<Sub Status>
- **个案所有人**：<Case Owner>
- **开始日期/时间**：<Date/Time Opened>

**客户信息：**
- **联系人**：<Contect Name>
- **客户名**：<Account Name>
- **权利名称**：<Entitlement Name>

**问题描述：**
简要描述客户的问题或需求（如有）

---

### 输出规则

- 禁止使用任何 emoji、表情
- 客户名称保持原样，不进行翻译或转换
- 未获取到的字段可留空或标记为 “未知”

---

## 失败判定

出现以下情况，则认为操作失败：

- agent-browser 执行报错
- Salesforce 需要进行登陆
- 未找到匹配的 Case
- 无法进入 Case 详情页

---

### 失败处理

如果操作判定为失败，返回具体失败原因。
