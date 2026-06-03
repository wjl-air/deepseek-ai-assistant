# RAG 检索增强生成功能设计文档

**项目**: DeepSeek AI 助手
**创建日期**: 2026-05-30
**版本**: 1.0

---

## 1. 概述

### 1.1 项目目标
为 DeepSeek AI 助手添加 RAG (Retrieval-Augmented Generation) 功能，使其能够：
- 基于上传的文档回答问题
- 深度检索和分析网络内容
- 提供可追溯的信息来源

### 1.2 分阶段实现计划

#### 阶段一：增强网络搜索 RAG
- 改进现有 web_search 工具
- 增加网页内容深度提取
- 添加搜索结果摘要和引用来源
- 支持多网页内容融合回答

#### 阶段二：文档 RAG 系统
- 支持 PDF、TXT、MD 等文档上传
- 文档分块和向量化存储
- 语义相似度检索
- 基于文档内容的问答

---

## 2. 系统架构

### 2.1 整体架构图

```
┌─────────────┐
│  用户输入    │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│  检索系统        │
│  ├─ 文档解析器   │
│  ├─ 向量检索器   │
│  └─ 网络搜索器   │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  知识增强层      │
│  └─ 检索结果注入 │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  AI 生成器       │
│  └─ 基于上下文   │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  输出层          │
│  ├─ 回答内容     │
│  └─ 来源引用     │
└──────────────────┘
```

### 2.2 代码结构

```
lib/
├── core/
│   ├── rag/
│   │   ├── web_content_extractor.dart   # 网页内容提取器
│   │   ├── content_summarizer.dart      # 内容摘要器
│   │   ├── search_result_processor.dart # 搜索结果处理器
│   │   └── rag_context_builder.dart     # RAG 上下文构建器
│   ├── models/
│   │   └── rag_search_result.dart       # RAG 搜索结果模型
│   └── tools/
│       └── tool_web_search.dart         # 增强版 web_search 工具
├── providers/
│   └── rag_provider.dart                # RAG 状态管理
└── ui/
    └── widgets/
        └── rag_source_indicator.dart    # RAG 来源指示器
```

---

## 3. 阶段一详细设计：增强网络搜索 RAG

### 3.1 功能描述

#### 3.1.1 深度内容抓取
- 从搜索结果中获取多个链接（3-5个）
- 并发抓取各网页内容
- 过滤广告、导航等噪声内容
- 提取文章主体文本

#### 3.1.2 智能摘要
- 对每个网页内容生成摘要（100-200字）
- 保留关键信息点
- 提取核心观点

#### 3.1.3 多源融合
- 整合多个网页的信息
- 去重和排序
- 构建统一的上下文

#### 3.1.4 来源引用
- 回答中标注信息来源
- 可点击链接跳转到原网页
- 显示来源网站名称

### 3.2 数据模型

#### RagSearchResult
```dart
class RagSearchResult {
  final String query;
  final List<WebSource> sources;
  final String combinedContext;

  RagSearchResult({
    required this.query,
    required this.sources,
    required this.combinedContext,
  });
}

class WebSource {
  final String url;
  final String title;
  final String snippet;
  final String content;
  final String summary;

  WebSource({
    required this.url,
    required this.title,
    required this.snippet,
    required this.content,
    required this.summary,
  });
}
```

### 3.3 数据流程

```
1. 用户提问
   ↓
2. AI 决定使用 web_search 工具
   ↓
3. 执行搜索，获取结果列表
   ↓
4. 并发抓取 top 3-5 网页
   ↓
5. 对每个网页：
   - 解析 HTML
   - 提取正文
   - 生成摘要
   ↓
6. 构建 RAG 上下文
   ↓
7. 注入提示词
   ↓
8. AI 基于增强上下文生成回答
   ↓
9. 输出回答 + 来源引用
```

### 3.4 API 设计

#### WebContentExtractor
```dart
class WebContentExtractor {
  Future<WebSource> extractFromUrl(String url);
  String extractMainContent(String html);
  String cleanText(String rawText);
}
```

#### ContentSummarizer
```dart
class ContentSummarizer {
  String summarize(String content, {int maxLength = 200});
  List<String> extractKeyPoints(String content);
}
```

#### SearchResultProcessor
```dart
class SearchResultProcessor {
  Future<RagSearchResult> processQuery(String query);
  List<WebSource> selectBestSources(List<WebSource> sources);
  String buildCombinedContext(List<WebSource> sources);
}
```

### 3.5 UI 设计

#### 3.5.1 搜索状态指示器
- 显示 "正在检索网页内容..."
- 显示进度条或加载动画

#### 3.5.2 来源引用展示
- 在回答底部显示来源列表
- 每个来源显示：图标 + 标题 + 链接
- 可点击跳转到原网页

#### 3.5.3 引用标注
- 回答中关键信息标注 [1]、[2] 等标记
- 悬停显示对应来源

### 3.6 依赖库

需要添加到 pubspec.yaml:
```yaml
dependencies:
  html: ^0.15.4    # HTML 解析
```

---

## 4. 阶段二设计预览：文档 RAG

### 4.1 功能概述
- 支持文档上传（PDF、TXT、MD）
- 文档分块和向量化
- 本地向量存储
- 语义相似度检索
- 基于文档内容的问答

### 4.2 技术要点
- 使用简单的 TF-IDF 或 BM25 进行检索（初期）
- 后续可升级到 embeddings
- 本地存储使用 SharedPreferences 或 SQLite

---

## 5. 非功能需求

### 5.1 性能
- 网页抓取超时：每页面 10 秒
- 总搜索响应时间：< 30 秒
- 支持取消操作

### 5.2 隐私
- 所有处理在客户端完成
- 不上传用户文档到第三方服务
- 可清除搜索历史

### 5.3 可扩展性
- 模块化设计
- 易于添加新的数据源
- 支持自定义检索算法

---

## 6. 风险与缓解

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 网页抓取失败 | 中 | 中 | 提供降级方案（使用摘要） |
| CORS 限制 | 高 | 高 | 使用代理或 JSONP（Web 环境） |
| 内容质量差 | 中 | 低 | 智能过滤和排序 |

---

## 7. 验收标准

### 阶段一验收
- [ ] 能够搜索并抓取多个网页内容
- [ ] 能够生成有用的摘要
- [ ] 回答中显示来源引用
- [ ] 点击引用可跳转原网页
- [ ] 响应时间在可接受范围内

---

## 8. 附录

### 8.1 相关文件
- [RAG 设计概念图](http://localhost:8080/rag-design.html)

### 8.2 参考资料
- RAG 技术原理论文
- Flutter Web 最佳实践
