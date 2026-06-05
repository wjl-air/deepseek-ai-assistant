class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = 'https://token-plan-cn.xiaomimimo.com/v1';
  // 支持编译时通过 --dart-define 注入，生产环境使用 /api 由 Nginx 代理
  // 使用相对路径，由 Nginx 反向代理到后端
  // 开发环境可通过 --dart-define 覆盖
  // 默认值设置为 /api，生产环境直接使用，开发环境通过 --dart-define=API_BASE_URL=http://localhost:8000 覆盖
  static const String backendApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '/api',  // 生产环境使用相对路径
  );
  static const String chatCompletionsPath = '/chat/completions';

  static const String apiKey = 'tp-cqemteapt69frj47fapp8eu8ppd4yggyg79dc6322dwq54m5';
  
  static const bool useMockChatService = false;

  static const String defaultModel = 'mimo-v2.5-pro';
  static const List<String> availableModels = [
    'mimo-v2.5-pro',
    'mimo-v2.5-flash',
  ];

  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 4096;
  static const int connectTimeoutMs = 30000;
  static const int receiveTimeoutMs = 120000;
  static const int maxImageSizeBytes = 20 * 1024 * 1024;
  static const int maxImageWidth = 2048;
  static const int maxImageHeight = 2048;

  static const String weatherApiKey = 'e9417f854591a36e1c4c652829988f25';
  static const String bochaApiKey = 'sk-77d284097eff496db8c11ecc7ef22b90';
  static const String weatherApiBaseUrl = 'https://api.openweathermap.org/data/2.5';

  static const String quickThinkingPrompt = '''# 未开启联网搜索模式
1. 只能使用2024年12月之前的内置知识库信息进行回答
2. 绝对不能编造或猜测2024年12月之后的任何信息
3. 绝对不能调用任何搜索工具
4. 如果用户询问的问题涉及以下内容，必须明确告知：
   "该信息超出了我的知识库范围（截止至2024年12月），请开启联网搜索功能后再次提问"
   - 2024年12月之后发生的事件、发布的产品、更新的版本
   - 实时信息（天气、股票、新闻、体育赛事结果、交通状况）
   - 需要最新数据的问题（价格、汇率、人口统计、政策变化）''';

  static const String deepThinkingPrompt = '''# 未开启联网搜索模式
1. 只能使用2024年12月之前的内置知识库信息进行回答
2. 绝对不能编造或猜测2024年12月之后的任何信息
3. 绝对不能调用任何搜索工具
4. 如果用户询问的问题涉及以下内容，必须明确告知：
   "该信息超出了我的知识库范围（截止至2024年12月），请开启联网搜索功能后再次提问"
   - 2024年12月之后发生的事件、发布的产品、更新的版本
   - 实时信息（天气、股票、新闻、体育赛事结果、交通状况）
   - 需要最新数据的问题（价格、汇率、人口统计、政策变化）

请仔细分析问题，展示你的思考过程：
1. 理解问题的核心
2. 分析可能的解决方法
3. 逐步推理
4. 给出最终答案''';

  static const String customThinkingPrompt = '''# 未开启联网搜索模式
1. 只能使用2024年12月之前的内置知识库信息进行回答
2. 绝对不能编造或猜测2024年12月之后的任何信息
3. 绝对不能调用任何搜索工具
4. 如果用户询问的问题涉及以下内容，必须明确告知：
   "该信息超出了我的知识库范围（截止至2024年12月），请开启联网搜索功能后再次提问"
   - 2024年12月之后发生的事件、发布的产品、更新的版本
   - 实时信息（天气、股票、新闻、体育赛事结果、交通状况）
   - 需要最新数据的问题（价格、汇率、人口统计、政策变化）''';

  static const String webSearchPrompt = '''# 开启联网搜索模式
1. 当前系统日期：{{CURRENT_DATE}}
2. 必须严格按照以下条件判断是否需要调用搜索工具：
   ✅ 必须调用搜索的情况：
   - 问题涉及2024年12月之后的事件、数据或信息
   - 问题涉及实时信息（天气、股票、新闻、体育赛事结果等）
   - 问题需要最新的产品信息、价格、版本号、下载链接
   - 问题需要官方最新政策、法规、公告
   - 知识库中没有相关信息或信息不完整
   
   ❌ 无需调用搜索的情况：
   - 常识性问题、基础概念解释
   - 2024年12月之前的历史事件、人物、知识
   - 数学计算、逻辑推理问题
   - 纯创意写作、代码编写（除非需要最新的API文档）

3. 搜索工具调用优先级：
   - 第一优先级：博查API
   - 第二优先级：DuckDuckGo（仅当博查API连续调用2次失败时自动回退）

5. 搜索结果使用规则：
   - 优先使用权威来源的信息（政府网站、官方网站、主流新闻媒体、学术数据库）
   - 对于存在争议的信息，需要同时列出不同来源的观点
   - 避免使用个人博客、论坛、社交媒体等非权威来源的信息作为主要依据
   - 回答时必须注明信息的来源和发布时间，例如："根据小米官网2026年5月发布的信息"
   - 对于同时涉及历史信息和最新信息的问题，先使用内置知识库回答历史部分，再用搜索结果补充最新部分

你也可以使用工具来翻译、转换单位和计算。''';

  static const String deepThinkingWithWebSearchPrompt = '''# 开启联网搜索模式
1. 当前系统日期：{{CURRENT_DATE}}
2. 必须严格按照以下条件判断是否需要调用搜索工具：
   ✅ 必须调用搜索的情况：
   - 问题涉及2024年12月之后的事件、数据或信息
   - 问题涉及实时信息（天气、股票、新闻、体育赛事结果等）
   - 问题需要最新的产品信息、价格、版本号、下载链接
   - 问题需要官方最新政策、法规、公告
   - 知识库中没有相关信息或信息不完整
   
   ❌ 无需调用搜索的情况：
   - 常识性问题、基础概念解释
   - 2024年12月之前的历史事件、人物、知识
   - 数学计算、逻辑推理问题
   - 纯创意写作、代码编写（除非需要最新的API文档）

3. 搜索工具调用优先级：
   - 第一优先级：博查API
   - 第二优先级：DuckDuckGo（仅当博查API连续调用2次失败时自动回退）

5. 搜索结果使用规则：
   - 优先使用权威来源的信息（政府网站、官方网站、主流新闻媒体、学术数据库）
   - 对于存在争议的信息，需要同时列出不同来源的观点
   - 避免使用个人博客、论坛、社交媒体等非权威来源的信息作为主要依据
   - 回答时必须注明信息的来源和发布时间，例如："根据小米官网2026年5月发布的信息"
   - 对于同时涉及历史信息和最新信息的问题，先使用内置知识库回答历史部分，再用搜索结果补充最新部分

请仔细分析问题，展示你的思考过程：
1. 理解问题的核心
2. 分析可能的解决方法
3. 逐步推理
4. 给出最终答案

你也可以使用工具来翻译、转换单位和计算。''';
}
