export const DEFAULT_LOCALE = 'en';
export const LOCALE_STORAGE_KEY = 'pushupai.locale';

export const LOCALES = Object.freeze([
  Object.freeze({ code: 'zh-CN', label: '简体中文', htmlLang: 'zh-CN' }),
  Object.freeze({ code: 'en', label: 'English', htmlLang: 'en' }),
  Object.freeze({ code: 'es', label: 'Español', htmlLang: 'es' }),
  Object.freeze({ code: 'fr', label: 'Français', htmlLang: 'fr' }),
  Object.freeze({ code: 'de', label: 'Deutsch', htmlLang: 'de' }),
  Object.freeze({
    code: 'pt-BR',
    label: 'Português (Brasil)',
    htmlLang: 'pt-BR',
  }),
  Object.freeze({ code: 'ja', label: '日本語', htmlLang: 'ja' }),
  Object.freeze({ code: 'ko', label: '한국어', htmlLang: 'ko' }),
]);

const aliases = Object.freeze({
  zh: 'zh-CN',
  en: 'en',
  es: 'es',
  fr: 'fr',
  de: 'de',
  pt: 'pt-BR',
  ja: 'ja',
  ko: 'ko',
});

const zhCN = Object.freeze({
  'meta.title': 'PushupAI · AI俯卧撑',
  'meta.description':
    '架好手机就能开始。PushupAI 自动计数、语音播报，也帮你记住每一次进步。',
  'meta.ogTitle': 'PushupAI · AI俯卧撑',
  'meta.ogDescription': '来做俯卧撑吧！AI 帮你数，放心去练。',
  'meta.ogLocale': 'zh_CN',
  'skip.main': '跳到主要内容',
  'brand.home': 'PushupAI 首页',
  'brand.productName': 'AI俯卧撑',
  'menu.open': '打开导航',
  'nav.label': '主要导航',
  'nav.features': '功能亮点',
  'nav.ecosystem': '一起坚持',
  'nav.how': '如何开始',
  'nav.faq': '常见问题',
  'nav.download': '下载',
  'header.status': '抢先体验',
  'language.label': '选择语言',
  'hero.eyebrow': '你的 AI 俯卧撑教练',
  'hero.titleAria': '来做俯卧撑吧！',
  'hero.titleLine1': '来做',
  'hero.titleLine2': '俯卧撑',
  'hero.titleLine3': '吧！',
  'hero.lede': 'AI 帮你数，放心去练。',
  'download.channelsLabel': '下载渠道',
  'store.googleStatus': 'Alpha 封闭测试',
  'store.appleStatus': '准备中',
  'store.available': '立即下载',
  'privacy.short': 'AI 看懂动作，你的训练画面，只属于你。',
  'hero.previewLabel': 'PushupAI App 界面预览',
  'hero.poseRecognized': '姿态已识别',
  'hero.sessionLabel': '本次完成',
  'hero.repsUnit': '次',
  'features.eyebrow': '专注训练本身',
  'features.titleLine1': '少一点操作，',
  'features.titleLine2': '多一次标准动作。',
  'features.intro': '镜头负责观察，PushupAI 负责计数。你只需要把注意力留给动作。',
  'features.countTitle': '看见动作，自动计数',
  'features.countBody':
    '不用分心数数，PushupAI 会跟上你的动作，自动记下每一次完成。',
  'features.privacyTitle': '你的训练，只属于你',
  'features.privacyBody': 'AI 只在手机里看懂动作，训练画面无需上传。',
  'features.recordsTitle': '每次进步，都有记录',
  'features.recordsBody': '每完成一次，语音都会及时告诉你；周、月、年的坚持，也会慢慢变成看得见的进步。',
  'showcase.eyebrow': '从开始到坚持',
  'showcase.title': '训练过程，清楚可见。',
  'showcase.intro': '简单的入口、醒目的计数、清晰的记录，每一屏都为训练服务。',
  'showcase.galleryLabel': 'App 页面展示',
  'showcase.homeAlt': 'AI俯卧撑首页，显示开始训练入口',
  'showcase.plazaAlt': 'PushupAI 运动广场榜单，显示日榜积分和本人排名',
  'showcase.workoutAlt': 'AI俯卧撑训练页，显示实时姿态识别和计数',
  'showcase.recordsAlt': 'AI俯卧撑训练记录，显示周月年统计入口',
  'showcase.settingsAlt': 'PushupAI 设置页，显示账号、语言和主题选项',
  'showcase.start': '一键开始',
  'showcase.recognize': '实时识别',
  'showcase.record': '留下记录',
  'ecosystem.eyebrow': '从训练到坚持',
  'ecosystem.titleAria': '不只记住这一次，也陪你坚持下一次。',
  'ecosystem.titleLine1': '不只记住这一次，',
  'ecosystem.titleLine2': '也陪你坚持下一次。',
  'ecosystem.intro': '从记录到排名，再到会员权益，一个账号帮你把每一次坚持连在一起。',
  'ecosystem.recordKicker': '记录',
  'ecosystem.syncTitle': '换一台设备，进步还在',
  'ecosystem.syncBody': '登录 Premium 会员后，训练记录就能跟着账号走；没有网络时，也不耽误训练。',
  'ecosystem.synced': '已同步',
  'ecosystem.plazaKicker': '运动广场',
  'ecosystem.rankingTitle': '和更多人一起挑战',
  'ecosystem.rankingBody': 'Premium 会员可以加入日榜和周榜，在匿名展示中看看今天的自己走到了哪里，也为下一次多一点动力。',
  'ecosystem.accountKicker': '账号',
  'ecosystem.accountTitle': '一个账号，一直陪着你',
  'ecosystem.accountBody': '登录 Google 账号，换设备也能找回会员权益、恢复购买，并继续使用之后解锁的更多能力。',
  'ecosystem.interfaceKicker': '界面',
  'ecosystem.interfaceTitle': '顺着你的习惯来',
  'ecosystem.interfaceBody': '中文和英文，浅色、深色，也会跟随系统主题，PushupAI 会配合你的设备和使用习惯。',
  'steps.eyebrow': '三步开始',
  'steps.title': '架好手机，马上开练。',
  'steps.intro': '不用穿戴设备，也不用复杂设置。一台手机，就是你的 AI 训练搭档。',
  'steps.fixTitle': '固定手机',
  'steps.fixBody': '把手机放在身体正前方，画面清楚、稳定就好。',
  'steps.noticeTitle': '确保自己清楚入镜',
  'steps.noticeBody': '让头、肩和身体清楚入镜，PushupAI 就准备好了。',
  'steps.trainTitle': '专心训练',
  'steps.trainBody': '点下开始，专心完成动作；计数和语音提醒都交给 PushupAI。',
  'steps.scope': '目前专注标准宽距俯卧撑，让每一次识别都更稳。',
  'faq.eyebrow': '开始之前',
  'faq.title': '你可能还想知道。',
  'faq.intro': '第一次使用？关于手机摆放、隐私、动作和记录，这里都为你说清楚。',
  'faq.positionQuestion': '手机应该放在哪里？',
  'faq.positionAnswer': '将手机固定在身体正前方，让头、肩和躯干完整入镜。保持画面稳定、光线充足，再按页面提示进入准备姿态。',
  'faq.privacyQuestion': '视频会上传吗？',
  'faq.privacyAnswerBefore': '不会上传原始视频帧。姿态识别和计数在设备端完成；训练记录只保存计数、时间等训练数据。详见',
  'faq.privacyPolicy': '隐私政策',
  'faq.privacyAnswerMiddle': '；如需离开服务，可查看',
  'faq.accountDeletion': '账号删除说明',
  'faq.privacyAnswerAfter': '。',
  'faq.actionsQuestion': '当前支持哪些动作？',
  'faq.actionsAnswer': '当前专注单人标准宽距俯卧撑，手机需要固定在正前方。近距离下压时肘腕短时离屏可以容错，但仍需保持头肩躯干可见。',
  'faq.syncQuestion': '训练记录如何同步？',
  'faq.syncAnswer': '本地训练无需登录即可使用。登录 Premium 会员后，可以把归属当前账号的记录同步到云端；云端暂不可用时，本地记录仍会正常显示。',
  'faq.downloadQuestion': '什么时候可以下载？',
  'faq.downloadAnswer': 'Google Play 0.3.4 已在 Alpha 封闭测试中面向测试人员发布；Android APK 0.3.4 现可直接下载。App Store 版本仍在准备。',
  'download.eyebrow': 'PushupAI · AI俯卧撑',
  'download.titleLine1': '下一次训练，',
  'download.titleLine2': '让每一下都有数。',
  'download.intro': 'PushupAI 正在与首批用户见面，更多下载方式即将开放。',
  'apk.kicker': 'Android 用户',
  'apk.title': '直接下载',
  'apk.body': '用 Android 手机扫码即可安装。',
  'apk.status': '0.3.4 已开放',
  'apk.placeholder': '0.3.4 · 317 MB',
  'apk.action': '点击下载安装包',
  'apk.qrLabel': '手机扫码下载',
  'apk.dialogTitle': 'Android 安装包',
  'apk.dialogPrompt': '是否下载 Android APK 安装包？',
  'apk.unavailable': '安装包正在准备中，开放后可在这里下载。',
  'apk.confirm': '继续下载',
  'apk.close': '关闭',
  'footer.top': '回到页面顶部',
  'footer.summary': 'AI 帮你数，陪你坚持每一次。',
  'footer.privacySummary': 'AI 看懂动作，你的训练画面，只属于你。',
  'footer.linksLabel': '隐私与账号',
  'footer.privacyPolicy': '隐私政策',
  'footer.accountDeletion': '账号删除',
});

const en = Object.freeze({
  'meta.title': 'PushupAI · AI Push-Up Coach',
  'meta.description':
    'Set up your phone and start. PushupAI counts reps, calls them out, and keeps every bit of progress in view.',
  'meta.ogTitle': 'PushupAI · AI Push-Up Coach',
  'meta.ogDescription': "Let's do some push-ups! AI counts. You just keep moving.",
  'meta.ogLocale': 'en_US',
  'skip.main': 'Skip to main content',
  'brand.home': 'PushupAI home',
  'brand.productName': 'AI Push-Up Coach',
  'menu.open': 'Open navigation',
  'nav.label': 'Primary navigation',
  'nav.features': 'Highlights',
  'nav.ecosystem': 'Keep going',
  'nav.how': 'Get started',
  'nav.faq': 'FAQ',
  'nav.download': 'Download',
  'header.status': 'Early access',
  'language.label': 'Choose language',
  'hero.eyebrow': 'Your AI push-up coach',
  'hero.titleAria': "Let's do some push-ups!",
  'hero.titleLine1': "Let's do",
  'hero.titleLine2': 'some',
  'hero.titleLine3': 'push-ups!',
  'hero.lede': 'AI counts. You just keep moving.',
  'download.channelsLabel': 'Download channels',
  'store.googleStatus': 'Closed Alpha',
  'store.appleStatus': 'In preparation',
  'store.available': 'Download now',
  'privacy.short': 'AI understands your movement. Your workout stays yours.',
  'hero.previewLabel': 'PushupAI app preview',
  'hero.poseRecognized': 'Pose recognized',
  'hero.sessionLabel': 'This session',
  'hero.repsUnit': 'reps',
  'features.eyebrow': 'Stay focused on training',
  'features.titleLine1': 'Less setup.',
  'features.titleLine2': 'More quality reps.',
  'features.intro':
    'The camera observes and PushupAI counts. You keep your attention on the movement.',
  'features.countTitle': 'See the movement. Count automatically.',
  'features.countBody':
    'Forget counting in your head. PushupAI follows your movement and records every completed rep.',
  'features.privacyTitle': 'Your workout is yours',
  'features.privacyBody':
    'AI understands your movement right on your phone, so your workout video never needs to be uploaded.',
  'features.recordsTitle': 'Every improvement, recorded',
  'features.recordsBody':
    'Hear every rep as it happens, then watch your weekly, monthly, and yearly effort turn into visible progress.',
  'showcase.eyebrow': 'From starting to staying consistent',
  'showcase.title': 'A clear view of every workout.',
  'showcase.intro':
    'A simple start, a bold counter, and clear records. Every screen serves the workout.',
  'showcase.galleryLabel': 'App screen gallery',
  'showcase.homeAlt': 'PushupAI home screen with the start workout action',
  'showcase.plazaAlt': 'PushupAI Sports Plaza with daily points and the current user\'s rank',
  'showcase.workoutAlt':
    'PushupAI workout screen with real-time pose recognition and counting',
  'showcase.recordsAlt':
    'PushupAI records screen with week, month, and year views',
  'showcase.settingsAlt':
    'PushupAI settings screen with account, language, and theme options',
  'showcase.start': 'Start in one tap',
  'showcase.recognize': 'Recognize in real time',
  'showcase.record': 'Keep the record',
  'ecosystem.eyebrow': 'From one workout to a lasting habit',
  'ecosystem.titleAria':
    'Remember this workout and help you return for the next one.',
  'ecosystem.titleLine1': 'Remember this workout.',
  'ecosystem.titleLine2': 'Return for the next one.',
  'ecosystem.intro':
    'From records to rankings and membership, one account keeps every part of your progress connected.',
  'ecosystem.recordKicker': 'Records',
  'ecosystem.syncTitle': 'New phone, same progress',
  'ecosystem.syncBody':
    'Sign in as a Premium member to carry your workout history with you. Even without a connection, you can keep training.',
  'ecosystem.synced': 'Synced',
  'ecosystem.plazaKicker': 'Sports Plaza',
  'ecosystem.rankingTitle': 'Take on the challenge together',
  'ecosystem.rankingBody':
    'Premium members can join daily and weekly rankings, see their progress with an anonymous public name, and find motivation for the next session.',
  'ecosystem.accountKicker': 'Account',
  'ecosystem.accountTitle': 'One account that stays with you',
  'ecosystem.accountBody':
    'Sign in with Google to bring back your membership, restore purchases, and keep future features with you on a new device.',
  'ecosystem.interfaceKicker': 'Interface',
  'ecosystem.interfaceTitle': 'Made for your routine',
  'ecosystem.interfaceBody':
    'Chinese or English, light, dark, or your system theme—PushupAI fits the way you use your device.',
  'steps.eyebrow': 'Start in three steps',
  'steps.title': 'Set up your phone. Start moving.',
  'steps.intro': 'No wearable. No complicated setup. One phone becomes your AI training partner.',
  'steps.fixTitle': 'Fix your phone in place',
  'steps.fixBody': 'Place your phone in front of you. A clear, steady view is all it needs.',
  'steps.noticeTitle': 'Make sure you are in view',
  'steps.noticeBody': 'Keep your head, shoulders, and body clearly visible, and PushupAI is ready.',
  'steps.trainTitle': 'Focus on training',
  'steps.trainBody':
    'Tap start and focus on your reps. PushupAI handles the counting and voice prompts.',
  'steps.scope':
    'For now, PushupAI focuses on standard wide-grip push-ups so every rep is recognized more reliably.',
  'faq.eyebrow': 'Before you begin',
  'faq.title': 'A few things you may want to know.',
  'faq.intro':
    'New here? Find clear answers about phone placement, privacy, movements, and records.',
  'faq.positionQuestion': 'Where should I place my phone?',
  'faq.positionAnswer':
    'Fix the phone directly in front of your body and keep your head, shoulders, and torso fully in frame. Keep the image stable and well lit, then follow the ready-pose guidance.',
  'faq.privacyQuestion': 'Are videos uploaded?',
  'faq.privacyAnswerBefore':
    'Original video frames are not uploaded. Pose recognition and counting happen on-device; workout records store training data such as count and time. Read the',
  'faq.privacyPolicy': 'Privacy Policy',
  'faq.privacyAnswerMiddle': 'or see the',
  'faq.accountDeletion': 'account deletion instructions',
  'faq.privacyAnswerAfter': '.',
  'faq.actionsQuestion': 'Which exercises are supported?',
  'faq.actionsAnswer':
    'The current version focuses on one-person standard wide-grip push-ups with a fixed front-facing phone. Brief elbow or wrist dropouts at close range are tolerated, but your head, shoulders, and torso must remain visible.',
  'faq.syncQuestion': 'How do workout records sync?',
  'faq.syncAnswer':
    'Local workouts work without signing in. Signed-in Premium members can sync records owned by the current account; local records continue to appear when the cloud is unavailable.',
  'faq.downloadQuestion': 'When can I download the app?',
  'faq.downloadAnswer':
    'Google Play 0.3.4 is available to Closed Alpha testers. Android APK 0.3.4 is now available for direct download; the App Store version is still in preparation.',
  'download.eyebrow': 'PushupAI · AI Push-Up Coach',
  'download.titleLine1': 'For your next workout,',
  'download.titleLine2': 'make every rep count.',
  'download.intro': 'PushupAI is meeting its first users now. More ways to download are coming soon.',
  'apk.kicker': 'Android users',
  'apk.title': 'Direct download',
  'apk.body': 'Scan with your Android phone to install.',
  'apk.status': '0.3.4 available',
  'apk.placeholder': '0.3.4 · 317 MB',
  'apk.action': 'Download the installation package',
  'apk.qrLabel': 'Scan with your phone',
  'apk.dialogTitle': 'Android installation package',
  'apk.dialogPrompt': 'Download the Android APK installation package?',
  'apk.unavailable': 'The installation package is being prepared. You can download it here once it is ready.',
  'apk.confirm': 'Continue download',
  'apk.close': 'Close',
  'footer.top': 'Back to top',
  'footer.summary': 'AI counts. You keep showing up.',
  'footer.privacySummary': 'AI understands your movement. Your workout stays yours.',
  'footer.linksLabel': 'Privacy and account',
  'footer.privacyPolicy': 'Privacy Policy',
  'footer.accountDeletion': 'Account deletion',
});

const es = Object.freeze({
  'meta.title': 'PushupAI · Entrenador de flexiones con IA',
  'meta.description':
    'Coloca el teléfono y empieza. PushupAI cuenta, te avisa por voz y guarda cada avance.',
  'meta.ogTitle': 'PushupAI · Entrenador de flexiones con IA',
  'meta.ogDescription': '¡Vamos a hacer flexiones! La IA cuenta. Tú solo sigue entrenando.',
  'meta.ogLocale': 'es_ES',
  'skip.main': 'Saltar al contenido principal',
  'brand.home': 'Inicio de PushupAI',
  'brand.productName': 'Entrenador de flexiones con IA',
  'menu.open': 'Abrir navegación',
  'nav.label': 'Navegación principal',
  'nav.features': 'Lo mejor',
  'nav.ecosystem': 'Sigue avanzando',
  'nav.how': 'Cómo empezar',
  'nav.faq': 'Preguntas',
  'nav.download': 'Descargar',
  'header.status': 'Acceso anticipado',
  'language.label': 'Elegir idioma',
  'hero.eyebrow': 'Tu entrenador de flexiones con IA',
  'hero.titleAria': '¡Vamos a hacer flexiones!',
  'hero.titleLine1': '¡Vamos',
  'hero.titleLine2': 'a hacer',
  'hero.titleLine3': 'flexiones!',
  'hero.lede': 'La IA cuenta. Tú solo sigue entrenando.',
  'download.channelsLabel': 'Canales de descarga',
  'store.googleStatus': 'Alfa cerrada',
  'store.appleStatus': 'En preparación',
  'store.available': 'Descargar ahora',
  'privacy.short': 'La IA entiende tus movimientos. Tu entrenamiento es solo tuyo.',
  'hero.previewLabel': 'Vista previa de la app PushupAI',
  'hero.poseRecognized': 'Postura reconocida',
  'hero.sessionLabel': 'Esta sesión',
  'hero.repsUnit': 'reps',
  'features.eyebrow': 'Céntrate en entrenar',
  'features.titleLine1': 'Menos preparación.',
  'features.titleLine2': 'Más repeticiones de calidad.',
  'features.intro':
    'La cámara observa y PushupAI cuenta. Tú mantienes la atención en el movimiento.',
  'features.countTitle': 'Ve el movimiento. Cuenta automáticamente.',
  'features.countBody':
    'Olvídate de contar. PushupAI sigue tus movimientos y guarda cada repetición completada.',
  'features.privacyTitle': 'Tu entrenamiento es tuyo',
  'features.privacyBody':
    'La IA entiende tus movimientos en el teléfono, sin necesidad de subir el video de tu entrenamiento.',
  'features.recordsTitle': 'Cada mejora queda registrada',
  'features.recordsBody':
    'Escucha cada repetición y mira cómo tu esfuerzo semanal, mensual y anual se convierte en progreso.',
  'showcase.eyebrow': 'De empezar a mantener el hábito',
  'showcase.title': 'Cada entrenamiento, claramente visible.',
  'showcase.intro':
    'Un inicio sencillo, un contador destacado y registros claros. Cada pantalla sirve al entrenamiento.',
  'showcase.galleryLabel': 'Galería de pantallas de la app',
  'showcase.homeAlt': 'Inicio de PushupAI con la acción para entrenar',
  'showcase.plazaAlt':
    'Clasificación de la Plaza Deportiva de PushupAI con puntos diarios y la posición del usuario',
  'showcase.workoutAlt':
    'Pantalla de entrenamiento con reconocimiento y conteo en tiempo real',
  'showcase.recordsAlt':
    'Registros de PushupAI con vistas semanal, mensual y anual',
  'showcase.settingsAlt':
    'Ajustes de PushupAI con opciones de cuenta, idioma y tema',
  'showcase.start': 'Empieza con un toque',
  'showcase.recognize': 'Reconoce en tiempo real',
  'showcase.record': 'Guarda el registro',
  'ecosystem.eyebrow': 'De un entrenamiento a un hábito',
  'ecosystem.titleAria':
    'Recuerda este entrenamiento y vuelve para el siguiente.',
  'ecosystem.titleLine1': 'Recuerda este entrenamiento.',
  'ecosystem.titleLine2': 'Vuelve para el siguiente.',
  'ecosystem.intro':
    'Registros, clasificaciones y membresía: una sola cuenta mantiene unido todo tu progreso.',
  'ecosystem.recordKicker': 'Registros',
  'ecosystem.syncTitle': 'Nuevo teléfono, el mismo progreso',
  'ecosystem.syncBody':
    'Inicia sesión como miembro Premium para llevar tu historial contigo. Incluso sin conexión, puedes seguir entrenando.',
  'ecosystem.synced': 'Sincronizado',
  'ecosystem.plazaKicker': 'Plaza deportiva',
  'ecosystem.rankingTitle': 'Acepta el reto con más personas',
  'ecosystem.rankingBody':
    'Los miembros Premium pueden unirse a las clasificaciones diarias y semanales, ver su avance con un nombre público anónimo y encontrar nueva motivación.',
  'ecosystem.accountKicker': 'Cuenta',
  'ecosystem.accountTitle': 'Una cuenta que te acompaña',
  'ecosystem.accountBody':
    'Inicia sesión con Google para recuperar tu membresía, restaurar compras y llevar las próximas funciones a un nuevo dispositivo.',
  'ecosystem.interfaceKicker': 'Interfaz',
  'ecosystem.interfaceTitle': 'A tu manera',
  'ecosystem.interfaceBody':
    'En chino o inglés, con tema claro, oscuro o el del sistema, PushupAI se adapta a tus hábitos.',
  'steps.eyebrow': 'Empieza en tres pasos',
  'steps.title': 'Coloca el teléfono. Empieza a moverte.',
  'steps.intro':
    'Sin accesorios ni configuraciones complicadas. Un teléfono es tu compañero de entrenamiento con IA.',
  'steps.fixTitle': 'Fija el teléfono',
  'steps.fixBody': 'Coloca el teléfono delante de ti. Solo necesita una imagen clara y estable.',
  'steps.noticeTitle': 'Asegúrate de aparecer en pantalla',
  'steps.noticeBody': 'Mantén la cabeza, los hombros y el cuerpo visibles, y PushupAI estará listo.',
  'steps.trainTitle': 'Concéntrate en entrenar',
  'steps.trainBody':
    'Pulsa empezar y concéntrate en tus flexiones. PushupAI se ocupa del conteo y los avisos de voz.',
  'steps.scope':
    'Por ahora, PushupAI se centra en flexiones estándar con agarre amplio para reconocer mejor cada repetición.',
  'faq.eyebrow': 'Antes de empezar',
  'faq.title': 'Quizá también quieras saber esto.',
  'faq.intro':
    '¿Es tu primera vez? Aquí aclaramos la colocación, la privacidad, los movimientos y los registros.',
  'faq.positionQuestion': '¿Dónde coloco el teléfono?',
  'faq.positionAnswer':
    'Fíjalo directamente delante del cuerpo y mantén cabeza, hombros y torso completos en cuadro. Asegura estabilidad y buena luz y sigue la guía de postura inicial.',
  'faq.privacyQuestion': '¿Se suben los videos?',
  'faq.privacyAnswerBefore':
    'Los fotogramas originales no se suben. El reconocimiento y el conteo ocurren en el dispositivo; los registros guardan datos como repeticiones y tiempo. Lee la',
  'faq.privacyPolicy': 'Política de privacidad',
  'faq.privacyAnswerMiddle': 'o consulta las',
  'faq.accountDeletion': 'instrucciones para eliminar la cuenta',
  'faq.privacyAnswerAfter': '.',
  'faq.actionsQuestion': '¿Qué ejercicios son compatibles?',
  'faq.actionsAnswer':
    'La versión actual se centra en flexiones estándar de agarre amplio para una persona, con teléfono fijo al frente. Tolera pérdidas breves de codos o muñecas a corta distancia, pero cabeza, hombros y torso deben seguir visibles.',
  'faq.syncQuestion': '¿Cómo se sincronizan los registros?',
  'faq.syncAnswer':
    'Los entrenamientos locales funcionan sin iniciar sesión. Los miembros Premium pueden sincronizar registros de la cuenta actual; los datos locales siguen visibles si la nube no está disponible.',
  'faq.downloadQuestion': '¿Cuándo podré descargar la app?',
  'faq.downloadAnswer':
    'Google Play 0.3.4 está disponible para los testers de la Alfa cerrada. El APK de Android 0.3.4 ya se puede descargar directamente; la versión de App Store sigue en preparación.',
  'download.eyebrow': 'PushupAI · Flexiones con IA',
  'download.titleLine1': 'En tu próximo entrenamiento,',
  'download.titleLine2': 'haz que cada repetición cuente.',
  'download.intro':
    'PushupAI ya está con sus primeros usuarios. Muy pronto habrá más formas de descargarlo.',
  'apk.kicker': 'Usuarios de Android',
  'apk.title': 'Descarga directa',
  'apk.body': 'Escanea el código con tu Android para instalarlo.',
  'apk.status': '0.3.4 disponible',
  'apk.placeholder': '0.3.4 · 317 MB',
  'apk.action': 'Descargar el paquete de instalación',
  'apk.qrLabel': 'Escanea con tu teléfono',
  'apk.dialogTitle': 'Paquete de instalación para Android',
  'apk.dialogPrompt': '¿Descargar el paquete de instalación Android APK?',
  'apk.unavailable': 'El paquete de instalación está en preparación. Podrás descargarlo aquí cuando esté listo.',
  'apk.confirm': 'Continuar descarga',
  'apk.close': 'Cerrar',
  'footer.top': 'Volver arriba',
  'footer.summary': 'La IA cuenta. Tú sigues avanzando.',
  'footer.privacySummary': 'La IA entiende tus movimientos. Tu entrenamiento es solo tuyo.',
  'footer.linksLabel': 'Privacidad y cuenta',
  'footer.privacyPolicy': 'Política de privacidad',
  'footer.accountDeletion': 'Eliminar cuenta',
});

const fr = Object.freeze({
  'meta.title': 'PushupAI · Coach de pompes par IA',
  'meta.description':
    'Posez le téléphone et commencez. PushupAI compte, annonce chaque répétition et garde vos progrès en vue.',
  'meta.ogTitle': 'PushupAI · Coach de pompes par IA',
  'meta.ogDescription': 'C’est parti pour les pompes ! L’IA compte. Vous n’avez plus qu’à bouger.',
  'meta.ogLocale': 'fr_FR',
  'skip.main': 'Aller au contenu principal',
  'brand.home': 'Accueil PushupAI',
  'brand.productName': 'Coach de pompes par IA',
  'menu.open': 'Ouvrir la navigation',
  'nav.label': 'Navigation principale',
  'nav.features': 'Points forts',
  'nav.ecosystem': 'Aller plus loin',
  'nav.how': 'Bien démarrer',
  'nav.faq': 'Questions',
  'nav.download': 'Télécharger',
  'header.status': 'Accès anticipé',
  'language.label': 'Choisir la langue',
  'hero.eyebrow': 'Votre coach de pompes par IA',
  'hero.titleAria': 'C’est parti pour les pompes !',
  'hero.titleLine1': 'C’est parti',
  'hero.titleLine2': 'pour les',
  'hero.titleLine3': 'pompes !',
  'hero.lede': 'L’IA compte. Vous n’avez plus qu’à bouger.',
  'download.channelsLabel': 'Canaux de téléchargement',
  'store.googleStatus': 'Alpha fermée',
  'store.appleStatus': 'En préparation',
  'store.available': 'Télécharger',
  'privacy.short': 'L’IA comprend vos mouvements. Votre entraînement reste à vous.',
  'hero.previewLabel': 'Aperçu de l’application PushupAI',
  'hero.poseRecognized': 'Posture reconnue',
  'hero.sessionLabel': 'Cette séance',
  'hero.repsUnit': 'rép.',
  'features.eyebrow': 'Restez concentré sur l’entraînement',
  'features.titleLine1': 'Moins de réglages.',
  'features.titleLine2': 'Plus de bonnes répétitions.',
  'features.intro':
    'La caméra observe et PushupAI compte. Vous gardez votre attention sur le mouvement.',
  'features.countTitle': 'Le mouvement est vu. Le compte est automatique.',
  'features.countBody':
    'Oubliez le comptage. PushupAI suit vos mouvements et garde chaque répétition terminée.',
  'features.privacyTitle': 'Votre entraînement reste à vous',
  'features.privacyBody':
    'L’IA comprend vos mouvements directement sur votre téléphone, sans avoir à envoyer votre vidéo.',
  'features.recordsTitle': 'Chaque progrès est enregistré',
  'features.recordsBody':
    'Entendez chaque répétition, puis regardez vos efforts de la semaine, du mois et de l’année devenir des progrès visibles.',
  'showcase.eyebrow': 'Du premier essai à la régularité',
  'showcase.title': 'Chaque séance, clairement visible.',
  'showcase.intro':
    'Un départ simple, un compteur lisible et des historiques clairs. Chaque écran sert l’entraînement.',
  'showcase.galleryLabel': 'Galerie des écrans de l’application',
  'showcase.homeAlt': 'Accueil PushupAI avec le bouton de démarrage',
  'showcase.plazaAlt':
    'Classement Sports Plaza de PushupAI avec les points du jour et le rang de l’utilisateur',
  'showcase.workoutAlt':
    'Écran d’entraînement PushupAI avec reconnaissance et comptage en temps réel',
  'showcase.recordsAlt':
    'Historique PushupAI avec vues semaine, mois et année',
  'showcase.settingsAlt':
    'Réglages PushupAI avec les options de compte, de langue et de thème',
  'showcase.start': 'Démarrer en un geste',
  'showcase.recognize': 'Reconnaître en temps réel',
  'showcase.record': 'Garder une trace',
  'ecosystem.eyebrow': 'D’une séance à une habitude',
  'ecosystem.titleAria':
    'Gardez cette séance en mémoire et revenez pour la suivante.',
  'ecosystem.titleLine1': 'Gardez cette séance.',
  'ecosystem.titleLine2': 'Revenez pour la suivante.',
  'ecosystem.intro':
    'Historique, classements et abonnement : un seul compte relie tous vos progrès.',
  'ecosystem.recordKicker': 'Historique',
  'ecosystem.syncTitle': 'Nouveau téléphone, mêmes progrès',
  'ecosystem.syncBody':
    'Connectez-vous comme membre Premium pour emporter votre historique. Même sans connexion, vous pouvez continuer à vous entraîner.',
  'ecosystem.synced': 'Synchronisé',
  'ecosystem.plazaKicker': 'Espace sportif',
  'ecosystem.rankingTitle': 'Relevez le défi ensemble',
  'ecosystem.rankingBody':
    'Les membres Premium peuvent rejoindre les classements du jour et de la semaine, suivre leurs progrès sous un nom public anonyme et trouver l’envie de recommencer.',
  'ecosystem.accountKicker': 'Compte',
  'ecosystem.accountTitle': 'Un compte qui vous accompagne',
  'ecosystem.accountBody':
    'Connectez-vous avec Google pour retrouver votre abonnement, restaurer vos achats et garder les prochaines fonctions sur un nouvel appareil.',
  'ecosystem.interfaceKicker': 'Interface',
  'ecosystem.interfaceTitle': 'À votre façon',
  'ecosystem.interfaceBody':
    'En chinois ou en anglais, en clair, en sombre ou selon le système, PushupAI s’adapte à vos habitudes.',
  'steps.eyebrow': 'Commencez en trois étapes',
  'steps.title': 'Posez le téléphone. Commencez à bouger.',
  'steps.intro':
    'Aucun accessoire, aucun réglage compliqué. Un téléphone devient votre coach IA.',
  'steps.fixTitle': 'Fixez le téléphone',
  'steps.fixBody': 'Placez le téléphone devant vous. Une image claire et stable suffit.',
  'steps.noticeTitle': 'Vérifiez que vous êtes visible',
  'steps.noticeBody': 'Gardez la tête, les épaules et le corps bien visibles, et PushupAI est prêt.',
  'steps.trainTitle': 'Concentrez-vous sur l’effort',
  'steps.trainBody':
    'Touchez démarrer et concentrez-vous sur vos pompes. PushupAI compte et vous guide à la voix.',
  'steps.scope':
    'Pour l’instant, PushupAI se concentre sur les pompes standard à prise large pour mieux reconnaître chaque répétition.',
  'faq.eyebrow': 'Avant de commencer',
  'faq.title': 'Quelques réponses utiles.',
  'faq.intro':
    'Première séance ? Retrouvez ici des réponses claires sur le placement, la confidentialité, les mouvements et l’historique.',
  'faq.positionQuestion': 'Où placer le téléphone ?',
  'faq.positionAnswer':
    'Fixez-le directement face au corps et gardez tête, épaules et torse entièrement visibles. Stabilisez l’image, assurez un bon éclairage puis suivez le guide de posture.',
  'faq.privacyQuestion': 'Les vidéos sont-elles envoyées ?',
  'faq.privacyAnswerBefore':
    'Les images vidéo originales ne sont pas envoyées. La reconnaissance et le comptage ont lieu sur l’appareil ; l’historique conserve des données comme le nombre et la durée. Lisez la',
  'faq.privacyPolicy': 'Politique de confidentialité',
  'faq.privacyAnswerMiddle': 'ou consultez les',
  'faq.accountDeletion': 'instructions de suppression du compte',
  'faq.privacyAnswerAfter': '.',
  'faq.actionsQuestion': 'Quels exercices sont pris en charge ?',
  'faq.actionsAnswer':
    'La version actuelle se concentre sur les pompes standard à prise large pour une personne, avec téléphone fixe de face. De brèves pertes des coudes ou poignets à courte distance sont tolérées, mais tête, épaules et torse doivent rester visibles.',
  'faq.syncQuestion': 'Comment synchroniser l’historique ?',
  'faq.syncAnswer':
    'Les séances locales fonctionnent sans connexion. Les membres Premium peuvent synchroniser les données du compte actuel ; l’historique local reste visible si le cloud est indisponible.',
  'faq.downloadQuestion': 'Quand pourrai-je télécharger l’app ?',
  'faq.downloadAnswer':
    'Google Play 0.3.4 est disponible pour les testeurs de l’Alpha fermée. L’APK Android 0.3.4 est maintenant disponible en téléchargement direct ; la version App Store est toujours en préparation.',
  'download.eyebrow': 'PushupAI · Pompes avec IA',
  'download.titleLine1': 'Pour votre prochaine séance,',
  'download.titleLine2': 'faites compter chaque répétition.',
  'download.intro':
    'PushupAI rencontre déjà ses premiers utilisateurs. D’autres façons de le télécharger arrivent bientôt.',
  'apk.kicker': 'Utilisateurs Android',
  'apk.title': 'Téléchargement direct',
  'apk.body': 'Scannez le code avec votre téléphone Android pour l’installer.',
  'apk.status': '0.3.4 disponible',
  'apk.placeholder': '0.3.4 · 317 MB',
  'apk.action': 'Télécharger le fichier d’installation',
  'apk.qrLabel': 'Scannez avec votre téléphone',
  'apk.dialogTitle': 'Fichier d’installation Android',
  'apk.dialogPrompt': 'Télécharger le fichier d’installation Android APK ?',
  'apk.unavailable': 'Le fichier d’installation est en préparation. Vous pourrez le télécharger ici dès qu’il sera prêt.',
  'apk.confirm': 'Continuer le téléchargement',
  'apk.close': 'Fermer',
  'footer.top': 'Retour en haut',
  'footer.summary': 'L’IA compte. Vous continuez à avancer.',
  'footer.privacySummary': 'L’IA comprend vos mouvements. Votre entraînement reste à vous.',
  'footer.linksLabel': 'Confidentialité et compte',
  'footer.privacyPolicy': 'Politique de confidentialité',
  'footer.accountDeletion': 'Supprimer le compte',
});

const de = Object.freeze({
  'meta.title': 'PushupAI · KI-Liegestütz-Coach',
  'meta.description':
    'Smartphone aufstellen und loslegen. PushupAI zählt, sagt Wiederholungen an und hält jeden Fortschritt fest.',
  'meta.ogTitle': 'PushupAI · KI-Liegestütz-Coach',
  'meta.ogDescription': "Los geht's mit Liegestützen! Die KI zählt. Du konzentrierst dich aufs Training.",
  'meta.ogLocale': 'de_DE',
  'skip.main': 'Zum Hauptinhalt springen',
  'brand.home': 'PushupAI Startseite',
  'brand.productName': 'KI-Liegestütz-Coach',
  'menu.open': 'Navigation öffnen',
  'nav.label': 'Hauptnavigation',
  'nav.features': 'Highlights',
  'nav.ecosystem': 'Dranbleiben',
  'nav.how': 'Loslegen',
  'nav.faq': 'FAQ',
  'nav.download': 'Download',
  'header.status': 'Frühzugang',
  'language.label': 'Sprache wählen',
  'hero.eyebrow': 'Dein KI-Liegestütz-Coach',
  'hero.titleAria': "Los geht's mit Liegestützen!",
  'hero.titleLine1': "Los geht's",
  'hero.titleLine2': 'mit',
  'hero.titleLine3': 'Liegestützen!',
  'hero.lede': 'Die KI zählt. Du konzentrierst dich aufs Training.',
  'download.channelsLabel': 'Download-Kanäle',
  'store.googleStatus': 'Geschlossene Alpha',
  'store.appleStatus': 'In Vorbereitung',
  'store.available': 'Jetzt herunterladen',
  'privacy.short': 'Die KI versteht deine Bewegung. Dein Training bleibt deins.',
  'hero.previewLabel': 'Vorschau der PushupAI App',
  'hero.poseRecognized': 'Pose erkannt',
  'hero.sessionLabel': 'Dieses Training',
  'hero.repsUnit': 'Wdh.',
  'features.eyebrow': 'Volle Konzentration aufs Training',
  'features.titleLine1': 'Weniger Bedienung.',
  'features.titleLine2': 'Mehr saubere Wiederholungen.',
  'features.intro':
    'Die Kamera beobachtet und PushupAI zählt. Du konzentrierst dich auf die Bewegung.',
  'features.countTitle': 'Bewegung erkennen. Automatisch zählen.',
  'features.countBody':
    'Vergiss das Mitzählen. PushupAI folgt deiner Bewegung und hält jede fertige Wiederholung fest.',
  'features.privacyTitle': 'Dein Training bleibt deins',
  'features.privacyBody':
    'Die KI versteht deine Bewegung direkt auf deinem Smartphone. Dein Trainingsvideo muss nicht hochgeladen werden.',
  'features.recordsTitle': 'Jeder Fortschritt wird festgehalten',
  'features.recordsBody':
    'Höre jede Wiederholung sofort und sieh, wie Wochen, Monate und Jahre Einsatz zu echtem Fortschritt werden.',
  'showcase.eyebrow': 'Vom Start zur Beständigkeit',
  'showcase.title': 'Jedes Training klar im Blick.',
  'showcase.intro':
    'Ein einfacher Start, ein gut sichtbarer Zähler und klare Aufzeichnungen. Jeder Bildschirm dient dem Training.',
  'showcase.galleryLabel': 'Galerie der App-Bildschirme',
  'showcase.homeAlt': 'PushupAI Startbildschirm mit Trainingsstart',
  'showcase.plazaAlt':
    'PushupAI Sports Plaza mit Tagespunkten und dem Rang des aktuellen Nutzers',
  'showcase.workoutAlt':
    'PushupAI Trainingsbildschirm mit Echtzeit-Erkennung und Zählung',
  'showcase.recordsAlt':
    'PushupAI Aufzeichnungen mit Wochen-, Monats- und Jahresansicht',
  'showcase.settingsAlt':
    'PushupAI Einstellungen mit Konto-, Sprach- und Designoptionen',
  'showcase.start': 'Mit einem Tippen starten',
  'showcase.recognize': 'In Echtzeit erkennen',
  'showcase.record': 'Fortschritt festhalten',
  'ecosystem.eyebrow': 'Vom Training zur Gewohnheit',
  'ecosystem.titleAria':
    'Dieses Training merken und zum nächsten zurückkehren.',
  'ecosystem.titleLine1': 'Dieses Training merken.',
  'ecosystem.titleLine2': 'Zum nächsten zurückkehren.',
  'ecosystem.intro':
    'Verlauf, Ranglisten und Mitgliedschaft: Ein Konto verbindet deinen ganzen Fortschritt.',
  'ecosystem.recordKicker': 'Aufzeichnungen',
  'ecosystem.syncTitle': 'Neues Smartphone, gleicher Fortschritt',
  'ecosystem.syncBody':
    'Melde dich als Premium-Mitglied an und nimm deinen Trainingsverlauf mit. Auch ohne Verbindung kannst du weitertrainieren.',
  'ecosystem.synced': 'Synchronisiert',
  'ecosystem.plazaKicker': 'Sportplatz',
  'ecosystem.rankingTitle': 'Gemeinsam die Challenge annehmen',
  'ecosystem.rankingBody':
    'Premium-Mitglieder können bei Tages- und Wochenranglisten mitmachen, ihren Fortschritt unter einem anonymen öffentlichen Namen sehen und neue Motivation finden.',
  'ecosystem.accountKicker': 'Konto',
  'ecosystem.accountTitle': 'Ein Konto, das dich begleitet',
  'ecosystem.accountBody':
    'Melde dich mit Google an, um deine Mitgliedschaft und Käufe wiederherzustellen und kommende Funktionen aufs neue Gerät mitzunehmen.',
  'ecosystem.interfaceKicker': 'Oberfläche',
  'ecosystem.interfaceTitle': 'So, wie es zu dir passt',
  'ecosystem.interfaceBody':
    'Chinesisch oder Englisch, hell, dunkel oder wie dein System—PushupAI passt sich deinen Gewohnheiten an.',
  'steps.eyebrow': 'In drei Schritten starten',
  'steps.title': 'Smartphone aufstellen. Loslegen.',
  'steps.intro':
    'Kein Zubehör, keine komplizierte Einrichtung. Ein Smartphone wird zu deinem KI-Trainingspartner.',
  'steps.fixTitle': 'Smartphone fixieren',
  'steps.fixBody': 'Stelle das Smartphone vor dich. Ein klares, ruhiges Bild genügt.',
  'steps.noticeTitle': 'Achte darauf, dass du im Bild bist',
  'steps.noticeBody': 'Kopf, Schultern und Körper gut sichtbar? Dann ist PushupAI bereit.',
  'steps.trainTitle': 'Auf das Training konzentrieren',
  'steps.trainBody':
    'Tippe auf Start und konzentriere dich auf deine Liegestütze. PushupAI übernimmt Zählung und Sprachhinweise.',
  'steps.scope':
    'Im Moment konzentriert sich PushupAI auf Standard-Liegestütze mit breitem Griff, damit jede Wiederholung sicherer erkannt wird.',
  'faq.eyebrow': 'Vor dem Start',
  'faq.title': 'Was du vielleicht noch wissen möchtest.',
  'faq.intro':
    'Zum ersten Mal hier? Hier findest du klare Antworten zu Aufstellung, Datenschutz, Bewegungen und Verlauf.',
  'faq.positionQuestion': 'Wo soll das Smartphone stehen?',
  'faq.positionAnswer':
    'Fixiere es direkt vor dem Körper und halte Kopf, Schultern und Oberkörper vollständig im Bild. Sorge für Stabilität und gutes Licht und folge dann der Startpose.',
  'faq.privacyQuestion': 'Werden Videos hochgeladen?',
  'faq.privacyAnswerBefore':
    'Originale Videobilder werden nicht hochgeladen. Erkennung und Zählung laufen auf dem Gerät; Trainingsdaten speichern Angaben wie Anzahl und Zeit. Lies die',
  'faq.privacyPolicy': 'Datenschutzerklärung',
  'faq.privacyAnswerMiddle': 'oder die',
  'faq.accountDeletion': 'Anleitung zur Kontolöschung',
  'faq.privacyAnswerAfter': '.',
  'faq.actionsQuestion': 'Welche Übungen werden unterstützt?',
  'faq.actionsAnswer':
    'Die aktuelle Version konzentriert sich auf Standard-Liegestütze mit breitem Griff für eine Person und festem Smartphone von vorn. Kurze Ellbogen- oder Handgelenkausfälle aus der Nähe werden toleriert, Kopf, Schultern und Oberkörper müssen aber sichtbar bleiben.',
  'faq.syncQuestion': 'Wie werden Trainingsdaten synchronisiert?',
  'faq.syncAnswer':
    'Lokales Training funktioniert ohne Anmeldung. Premium-Mitglieder können Daten des aktuellen Kontos synchronisieren; lokale Aufzeichnungen bleiben auch bei nicht verfügbarer Cloud sichtbar.',
  'faq.downloadQuestion': 'Wann kann ich die App herunterladen?',
  'faq.downloadAnswer':
    'Google Play 0.3.4 ist für Tester der geschlossenen Alpha verfügbar. Die Android-APK 0.3.4 kann jetzt direkt heruntergeladen werden; die App-Store-Version wird weiterhin vorbereitet.',
  'download.eyebrow': 'PushupAI · KI-Liegestütze',
  'download.titleLine1': 'Beim nächsten Training',
  'download.titleLine2': 'zählt jede Wiederholung.',
  'download.intro':
    'PushupAI trainiert bereits mit den ersten Nutzern. Weitere Download-Möglichkeiten folgen bald.',
  'apk.kicker': 'Für Android-Nutzer',
  'apk.title': 'Direkter Download',
  'apk.body': 'Scanne den Code mit deinem Android-Smartphone, um die App zu installieren.',
  'apk.status': '0.3.4 verfügbar',
  'apk.placeholder': '0.3.4 · 317 MB',
  'apk.action': 'Installationspaket herunterladen',
  'apk.qrLabel': 'Mit dem Smartphone scannen',
  'apk.dialogTitle': 'Android-Installationspaket',
  'apk.dialogPrompt': 'Android-APK-Installationspaket herunterladen?',
  'apk.unavailable': 'Das Installationspaket wird vorbereitet. Sobald es verfügbar ist, kannst du es hier herunterladen.',
  'apk.confirm': 'Download fortsetzen',
  'apk.close': 'Schließen',
  'footer.top': 'Nach oben',
  'footer.summary': 'Die KI zählt. Du bleibst dran.',
  'footer.privacySummary': 'Die KI versteht deine Bewegung. Dein Training bleibt deins.',
  'footer.linksLabel': 'Datenschutz und Konto',
  'footer.privacyPolicy': 'Datenschutzerklärung',
  'footer.accountDeletion': 'Konto löschen',
});

const ptBR = Object.freeze({
  'meta.title': 'PushupAI · Treinador de flexões com IA',
  'meta.description':
    'Posicione o celular e comece. O PushupAI conta, avisa por voz e guarda cada avanço.',
  'meta.ogTitle': 'PushupAI · Treinador de flexões com IA',
  'meta.ogDescription': 'Vamos fazer flexões! A IA conta. Você só precisa treinar.',
  'meta.ogLocale': 'pt_BR',
  'skip.main': 'Ir para o conteúdo principal',
  'brand.home': 'Início do PushupAI',
  'brand.productName': 'Treinador de flexões com IA',
  'menu.open': 'Abrir navegação',
  'nav.label': 'Navegação principal',
  'nav.features': 'Destaques',
  'nav.ecosystem': 'Continue evoluindo',
  'nav.how': 'Como começar',
  'nav.faq': 'Dúvidas',
  'nav.download': 'Baixar',
  'header.status': 'Acesso antecipado',
  'language.label': 'Escolher idioma',
  'hero.eyebrow': 'Seu treinador de flexões com IA',
  'hero.titleAria': 'Vamos fazer flexões!',
  'hero.titleLine1': 'Vamos',
  'hero.titleLine2': 'fazer',
  'hero.titleLine3': 'flexões!',
  'hero.lede': 'A IA conta. Você só precisa treinar.',
  'download.channelsLabel': 'Canais de download',
  'store.googleStatus': 'Alpha fechado',
  'store.appleStatus': 'Em preparação',
  'store.available': 'Baixar agora',
  'privacy.short': 'A IA entende seus movimentos. Seu treino continua sendo só seu.',
  'hero.previewLabel': 'Prévia do app PushupAI',
  'hero.poseRecognized': 'Postura reconhecida',
  'hero.sessionLabel': 'Neste treino',
  'hero.repsUnit': 'reps',
  'features.eyebrow': 'Foque no treino',
  'features.titleLine1': 'Menos configuração.',
  'features.titleLine2': 'Mais repetições de qualidade.',
  'features.intro':
    'A câmera observa e o PushupAI conta. Você mantém a atenção no movimento.',
  'features.countTitle': 'Veja o movimento. Conte automaticamente.',
  'features.countBody':
    'Esqueça a contagem. O PushupAI acompanha seus movimentos e registra cada repetição concluída.',
  'features.privacyTitle': 'Seu treino é seu',
  'features.privacyBody':
    'A IA entende seus movimentos no celular, sem precisar enviar o vídeo do seu treino.',
  'features.recordsTitle': 'Cada progresso fica registrado',
  'features.recordsBody':
    'Ouça cada repetição na hora e veja semanas, meses e anos de esforço virarem progresso.',
  'showcase.eyebrow': 'Do começo à consistência',
  'showcase.title': 'Cada treino, claramente visível.',
  'showcase.intro':
    'Um início simples, um contador em destaque e registros claros. Cada tela serve ao treino.',
  'showcase.galleryLabel': 'Galeria de telas do app',
  'showcase.homeAlt': 'Tela inicial do PushupAI com a ação de iniciar treino',
  'showcase.plazaAlt':
    'Ranking da Praça Esportiva do PushupAI com pontos diários e a posição do usuário',
  'showcase.workoutAlt':
    'Tela de treino do PushupAI com reconhecimento e contagem em tempo real',
  'showcase.recordsAlt':
    'Registros do PushupAI com visões semanal, mensal e anual',
  'showcase.settingsAlt':
    'Configurações do PushupAI com opções de conta, idioma e tema',
  'showcase.start': 'Comece com um toque',
  'showcase.recognize': 'Reconheça em tempo real',
  'showcase.record': 'Guarde o registro',
  'ecosystem.eyebrow': 'De um treino a um hábito',
  'ecosystem.titleAria':
    'Lembre deste treino e volte para o próximo.',
  'ecosystem.titleLine1': 'Lembre deste treino.',
  'ecosystem.titleLine2': 'Volte para o próximo.',
  'ecosystem.intro':
    'Registros, rankings e assinatura: uma conta mantém todo o seu progresso conectado.',
  'ecosystem.recordKicker': 'Registros',
  'ecosystem.syncTitle': 'Celular novo, o mesmo progresso',
  'ecosystem.syncBody':
    'Entre como membro Premium para levar o histórico com você. Mesmo sem conexão, dá para continuar treinando.',
  'ecosystem.synced': 'Sincronizado',
  'ecosystem.plazaKicker': 'Praça esportiva',
  'ecosystem.rankingTitle': 'Encare o desafio com mais gente',
  'ecosystem.rankingBody':
    'Membros Premium podem entrar nos rankings diário e semanal, acompanhar o avanço com um nome público anônimo e ganhar motivação para o próximo treino.',
  'ecosystem.accountKicker': 'Conta',
  'ecosystem.accountTitle': 'Uma conta que acompanha você',
  'ecosystem.accountBody':
    'Entre com o Google para recuperar sua assinatura, restaurar compras e levar os próximos recursos para um novo aparelho.',
  'ecosystem.interfaceKicker': 'Interface',
  'ecosystem.interfaceTitle': 'Do seu jeito',
  'ecosystem.interfaceBody':
    'Em chinês ou inglês, no tema claro, escuro ou do sistema, o PushupAI se adapta aos seus hábitos.',
  'steps.eyebrow': 'Comece em três passos',
  'steps.title': 'Posicione o celular. Comece a se mover.',
  'steps.intro':
    'Sem acessórios e sem configuração complicada. Um celular vira seu parceiro de treino com IA.',
  'steps.fixTitle': 'Fixe o celular',
  'steps.fixBody': 'Coloque o celular à sua frente. Uma imagem clara e estável é o bastante.',
  'steps.noticeTitle': 'Garanta que você aparece na tela',
  'steps.noticeBody': 'Mantenha cabeça, ombros e corpo visíveis, e o PushupAI estará pronto.',
  'steps.trainTitle': 'Foque no treino',
  'steps.trainBody':
    'Toque em começar e foque nas flexões. O PushupAI cuida da contagem e dos avisos de voz.',
  'steps.scope':
    'Por enquanto, o PushupAI foca em flexões padrão com pegada aberta para reconhecer melhor cada repetição.',
  'faq.eyebrow': 'Antes de começar',
  'faq.title': 'Algumas coisas que você pode querer saber.',
  'faq.intro':
    'É sua primeira vez? Aqui você encontra respostas claras sobre posição, privacidade, movimentos e registros.',
  'faq.positionQuestion': 'Onde devo colocar o celular?',
  'faq.positionAnswer':
    'Fixe-o diretamente à frente do corpo e mantenha cabeça, ombros e tronco totalmente no quadro. Garanta estabilidade e boa luz e siga a orientação de postura inicial.',
  'faq.privacyQuestion': 'Os vídeos são enviados?',
  'faq.privacyAnswerBefore':
    'Os quadros originais não são enviados. Reconhecimento e contagem ocorrem no dispositivo; os registros guardam dados como contagem e tempo. Leia a',
  'faq.privacyPolicy': 'Política de Privacidade',
  'faq.privacyAnswerMiddle': 'ou veja as',
  'faq.accountDeletion': 'instruções para excluir a conta',
  'faq.privacyAnswerAfter': '.',
  'faq.actionsQuestion': 'Quais exercícios são compatíveis?',
  'faq.actionsAnswer':
    'A versão atual foca em flexões padrão com pegada aberta para uma pessoa e celular fixo de frente. Perdas breves de cotovelos ou punhos a curta distância são toleradas, mas cabeça, ombros e tronco devem permanecer visíveis.',
  'faq.syncQuestion': 'Como os registros são sincronizados?',
  'faq.syncAnswer':
    'Treinos locais funcionam sem login. Membros Premium podem sincronizar dados da conta atual; os registros locais continuam visíveis se a nuvem estiver indisponível.',
  'faq.downloadQuestion': 'Quando poderei baixar o app?',
  'faq.downloadAnswer':
    'O Google Play 0.3.4 está disponível para os testadores do Alpha fechado. O APK Android 0.3.4 já pode ser baixado diretamente; a versão da App Store continua em preparação.',
  'download.eyebrow': 'PushupAI · Flexões com IA',
  'download.titleLine1': 'No seu próximo treino,',
  'download.titleLine2': 'faça cada repetição contar.',
  'download.intro':
    'O PushupAI já está treinando com os primeiros usuários. Mais formas de baixar chegam em breve.',
  'apk.kicker': 'Usuários de Android',
  'apk.title': 'Download direto',
  'apk.body': 'Escaneie o código com seu Android para instalar.',
  'apk.status': '0.3.4 disponível',
  'apk.placeholder': '0.3.4 · 317 MB',
  'apk.action': 'Baixar o pacote de instalação',
  'apk.qrLabel': 'Escaneie com o celular',
  'apk.dialogTitle': 'Pacote de instalação para Android',
  'apk.dialogPrompt': 'Baixar o pacote de instalação Android APK?',
  'apk.unavailable': 'O pacote de instalação está sendo preparado. Você poderá baixá-lo aqui quando estiver pronto.',
  'apk.confirm': 'Continuar download',
  'apk.close': 'Fechar',
  'footer.top': 'Voltar ao topo',
  'footer.summary': 'A IA conta. Você continua evoluindo.',
  'footer.privacySummary': 'A IA entende seus movimentos. Seu treino continua sendo só seu.',
  'footer.linksLabel': 'Privacidade e conta',
  'footer.privacyPolicy': 'Política de Privacidade',
  'footer.accountDeletion': 'Excluir conta',
});

const ja = Object.freeze({
  'meta.title': 'PushupAI · AI腕立て伏せコーチ',
  'meta.description':
    'スマートフォンを置いたら、すぐスタート。PushupAIが回数を数え、声で知らせ、毎日の成長を残します。',
  'meta.ogTitle': 'PushupAI · AI腕立て伏せコーチ',
  'meta.ogDescription': 'さあ、腕立て伏せを始めよう！カウントはAIにおまかせ。あなたは動くだけ。',
  'meta.ogLocale': 'ja_JP',
  'skip.main': 'メインコンテンツへ',
  'brand.home': 'PushupAI ホーム',
  'brand.productName': 'AI腕立て伏せコーチ',
  'menu.open': 'ナビゲーションを開く',
  'nav.label': 'メインナビゲーション',
  'nav.features': 'できること',
  'nav.ecosystem': '続ける楽しさ',
  'nav.how': 'はじめ方',
  'nav.faq': 'よくある質問',
  'nav.download': 'ダウンロード',
  'header.status': '先行体験',
  'language.label': '言語を選択',
  'hero.eyebrow': 'あなたのAI腕立て伏せコーチ',
  'hero.titleAria': 'さあ、腕立て伏せを始めよう！',
  'hero.titleLine1': 'さあ、',
  'hero.titleLine2': '腕立て伏せを',
  'hero.titleLine3': '始めよう！',
  'hero.lede': 'カウントはAIにおまかせ。あなたは動くだけ。',
  'download.channelsLabel': 'ダウンロード方法',
  'store.googleStatus': 'クローズドAlpha',
  'store.appleStatus': '準備中',
  'store.available': '今すぐダウンロード',
  'privacy.short': 'AIが動きを見守る。トレーニング映像は、あなただけのもの。',
  'hero.previewLabel': 'PushupAI アプリのプレビュー',
  'hero.poseRecognized': '姿勢を認識',
  'hero.sessionLabel': '今回のセッション',
  'hero.repsUnit': '回',
  'features.eyebrow': 'トレーニングに集中',
  'features.titleLine1': '操作は少なく。',
  'features.titleLine2': '良いレップをもっと。',
  'features.intro':
    'カメラが見守り、PushupAIが数えます。あなたは動きに集中できます。',
  'features.countTitle': '動きを見て、自動カウント',
  'features.countBody':
    'もう自分で数えなくて大丈夫。PushupAIが動きについていき、できた1回をしっかり記録します。',
  'features.privacyTitle': 'あなたのトレーニングは、あなただけのもの',
  'features.privacyBody':
    'AIがスマートフォンの中で動きを見守るので、トレーニング映像を送る必要はありません。',
  'features.recordsTitle': 'すべての進歩を記録',
  'features.recordsBody':
    '1回ごとに声でお知らせ。週、月、年の積み重ねが、見える成長に変わります。',
  'showcase.eyebrow': '始めるから続けるまで',
  'showcase.title': 'トレーニングの流れを明確に。',
  'showcase.intro':
    'シンプルな開始、大きなカウンター、見やすい記録。すべての画面がトレーニングのためにあります。',
  'showcase.galleryLabel': 'アプリ画面ギャラリー',
  'showcase.homeAlt': 'トレーニング開始ボタンのあるPushupAIホーム画面',
  'showcase.plazaAlt': 'デイリーポイントと自分の順位を表示するPushupAIスポーツ広場ランキング',
  'showcase.workoutAlt':
    'リアルタイム姿勢認識とカウントを表示するPushupAIトレーニング画面',
  'showcase.recordsAlt':
    '週・月・年の表示を持つPushupAI記録画面',
  'showcase.settingsAlt': 'アカウント、言語、テーマ設定を表示するPushupAI設定画面',
  'showcase.start': '1タップで開始',
  'showcase.recognize': 'リアルタイム認識',
  'showcase.record': '記録を残す',
  'ecosystem.eyebrow': '1回のトレーニングから習慣へ',
  'ecosystem.titleAria':
    '今回を記録し、次回のトレーニングにつなげます。',
  'ecosystem.titleLine1': '今回を記録。',
  'ecosystem.titleLine2': '次回も続けられる。',
  'ecosystem.intro':
    '記録もランキングも会員特典も、ひとつのアカウントがあなたの頑張りをつなぎます。',
  'ecosystem.recordKicker': '記録',
  'ecosystem.syncTitle': 'スマホが変わっても、成長はそのまま',
  'ecosystem.syncBody':
    'Premium会員としてログインすれば、トレーニング記録を持ち歩けます。通信がなくても、いつもどおり運動できます。',
  'ecosystem.synced': '同期済み',
  'ecosystem.plazaKicker': 'スポーツ広場',
  'ecosystem.rankingTitle': 'みんなと一緒にチャレンジ',
  'ecosystem.rankingBody':
    'Premium会員は今日と今週のランキングに参加し、匿名の公開名で今の自分を確かめ、次のトレーニングの力にできます。',
  'ecosystem.accountKicker': 'アカウント',
  'ecosystem.accountTitle': 'ずっとつながる、ひとつのアカウント',
  'ecosystem.accountBody':
    'Googleでログインすれば、会員特典と購入を復元し、これから増える楽しみも新しい端末で続けられます。',
  'ecosystem.interfaceKicker': 'インターフェース',
  'ecosystem.interfaceTitle': 'いつもの使い方に、すっとなじむ',
  'ecosystem.interfaceBody':
    '中国語でも英語でも、ライト、ダーク、システム設定でも、PushupAIがあなたの好みに寄り添います。',
  'steps.eyebrow': '3ステップで開始',
  'steps.title': 'スマホを置いて、すぐスタート。',
  'steps.intro':
    '特別な道具も難しい設定も不要。スマートフォン1台がAIトレーニングパートナーになります。',
  'steps.fixTitle': 'スマートフォンを固定',
  'steps.fixBody': 'スマートフォンを正面に置き、明るく安定した画面にするだけ。',
  'steps.noticeTitle': '画面に入っているかチェック',
  'steps.noticeBody': '頭、肩、体がはっきり見えたら、PushupAIの準備は完了です。',
  'steps.trainTitle': 'トレーニングに集中',
  'steps.trainBody':
    'スタートを押したら、腕立て伏せに集中。カウントと音声案内はPushupAIにおまかせ。',
  'steps.scope':
    '今はワイドスタンスの標準的な腕立て伏せに集中し、1回ずつをより安定して見守ります。',
  'faq.eyebrow': '始める前に',
  'faq.title': '知っておきたいこと。',
  'faq.intro':
    '初めてでも大丈夫。設置、プライバシー、動き、記録について、ここでわかりやすく答えます。',
  'faq.positionQuestion': 'スマートフォンはどこに置きますか？',
  'faq.positionAnswer':
    '体の正面に固定し、頭、肩、胴体全体が映るようにします。映像を安定させ、明るさを確保し、準備姿勢のガイドに従ってください。',
  'faq.privacyQuestion': '映像はアップロードされますか？',
  'faq.privacyAnswerBefore':
    '元の映像フレームはアップロードされません。認識とカウントはデバイス上で行われ、記録には回数や時間などのデータが保存されます。',
  'faq.privacyPolicy': 'プライバシーポリシー',
  'faq.privacyAnswerMiddle': 'または',
  'faq.accountDeletion': 'アカウント削除手順',
  'faq.privacyAnswerAfter': 'をご確認ください。',
  'faq.actionsQuestion': 'どのエクササイズに対応していますか？',
  'faq.actionsAnswer':
    '現在は、正面に固定したスマートフォンで行う1人用の標準的なワイドスタンス腕立て伏せに特化しています。近距離で肘や手首が短時間見えなくても許容しますが、頭、肩、胴体は見える必要があります。',
  'faq.syncQuestion': '記録はどのように同期されますか？',
  'faq.syncAnswer':
    'ローカルトレーニングはログインなしで使えます。Premium会員は現在のアカウントの記録を同期でき、クラウドが使えない場合もローカル記録は表示されます。',
  'faq.downloadQuestion': 'いつダウンロードできますか？',
  'faq.downloadAnswer':
    'Google Play 0.3.4はクローズドAlphaのテスター向けに公開されています。Android APK 0.3.4は直接ダウンロードできます。App Store版は引き続き準備中です。',
  'download.eyebrow': 'PushupAI · AI腕立て伏せ',
  'download.titleLine1': '次のトレーニングで、',
  'download.titleLine2': '1回ずつを大切に。',
  'download.intro':
    'PushupAIは最初のユーザーとトレーニングを始めています。ダウンロード方法は順次広がります。',
  'apk.kicker': 'Androidユーザーへ',
  'apk.title': '直接ダウンロード',
  'apk.body': 'Androidスマートフォンでコードを読み取ってインストールできます。',
  'apk.status': '0.3.4 公開中',
  'apk.placeholder': '0.3.4 · 317 MB',
  'apk.action': 'インストールパッケージをダウンロード',
  'apk.qrLabel': 'スマートフォンでスキャン',
  'apk.dialogTitle': 'Androidインストールパッケージ',
  'apk.dialogPrompt': 'Android APKインストールパッケージをダウンロードしますか？',
  'apk.unavailable': 'インストールパッケージを準備中です。公開後はこちらからダウンロードできます。',
  'apk.confirm': 'ダウンロードを続ける',
  'apk.close': '閉じる',
  'footer.top': 'ページ上部へ',
  'footer.summary': 'カウントはAIに。続けるのはあなたらしく。',
  'footer.privacySummary': 'AIが動きを見守る。トレーニング映像は、あなただけのもの。',
  'footer.linksLabel': 'プライバシーとアカウント',
  'footer.privacyPolicy': 'プライバシーポリシー',
  'footer.accountDeletion': 'アカウント削除',
});

const ko = Object.freeze({
  'meta.title': 'PushupAI · AI 푸시업 코치',
  'meta.description':
    '휴대폰을 세우고 바로 시작하세요. PushupAI가 횟수를 세고, 음성으로 알려 주고, 매일의 성장을 기록해요.',
  'meta.ogTitle': 'PushupAI · AI 푸시업 코치',
  'meta.ogDescription': '자, 푸시업을 시작해요! 카운트는 AI에게 맡기고, 운동에만 집중하세요.',
  'meta.ogLocale': 'ko_KR',
  'skip.main': '본문으로 바로가기',
  'brand.home': 'PushupAI 홈',
  'brand.productName': 'AI 푸시업 코치',
  'menu.open': '탐색 메뉴 열기',
  'nav.label': '주요 탐색',
  'nav.features': '주요 장점',
  'nav.ecosystem': '꾸준히 이어가기',
  'nav.how': '시작 방법',
  'nav.faq': '자주 묻는 질문',
  'nav.download': '다운로드',
  'header.status': '미리 체험하기',
  'language.label': '언어 선택',
  'hero.eyebrow': '나만의 AI 푸시업 코치',
  'hero.titleAria': '자, 푸시업을 시작해요!',
  'hero.titleLine1': '자,',
  'hero.titleLine2': '푸시업을',
  'hero.titleLine3': '시작해요!',
  'hero.lede': '카운트는 AI에게 맡기고, 운동에만 집중하세요.',
  'download.channelsLabel': '다운로드 경로',
  'store.googleStatus': '폐쇄형 Alpha',
  'store.appleStatus': '준비 중',
  'store.available': '지금 다운로드',
  'privacy.short': 'AI가 동작을 이해해요. 당신의 운동 영상은 오직 당신의 것.',
  'hero.previewLabel': 'PushupAI 앱 미리보기',
  'hero.poseRecognized': '자세 인식 완료',
  'hero.sessionLabel': '이번 세션',
  'hero.repsUnit': '회',
  'features.eyebrow': '운동 자체에 집중',
  'features.titleLine1': '조작은 더 적게.',
  'features.titleLine2': '좋은 반복은 더 많게.',
  'features.intro':
    '카메라가 관찰하고 PushupAI가 세어 줍니다. 사용자는 동작에만 집중하세요.',
  'features.countTitle': '동작을 보고 자동 카운트',
  'features.countBody':
    '이제 직접 셀 필요 없어요. PushupAI가 동작을 따라가며 완료한 푸시업을 하나씩 기록해요.',
  'features.privacyTitle': '당신의 운동은 당신의 것',
  'features.privacyBody':
    'AI가 휴대폰에서 동작을 이해하므로 운동 영상을 보낼 필요가 없어요.',
  'features.recordsTitle': '모든 발전을 기록',
  'features.recordsBody':
    '한 번을 마칠 때마다 바로 듣고, 주·월·년의 노력이 눈에 보이는 성장으로 바뀌는 걸 확인하세요.',
  'showcase.eyebrow': '시작에서 꾸준함까지',
  'showcase.title': '운동 과정을 명확하게.',
  'showcase.intro':
    '간단한 시작, 뚜렷한 카운터, 명확한 기록. 모든 화면이 운동을 위해 설계되었습니다.',
  'showcase.galleryLabel': '앱 화면 갤러리',
  'showcase.homeAlt': '운동 시작 버튼이 있는 PushupAI 홈 화면',
  'showcase.plazaAlt': '일일 포인트와 내 순위를 보여 주는 PushupAI 스포츠 광장 순위표',
  'showcase.workoutAlt':
    '실시간 자세 인식과 카운트를 보여 주는 PushupAI 운동 화면',
  'showcase.recordsAlt':
    '주간·월간·연간 보기가 있는 PushupAI 기록 화면',
  'showcase.settingsAlt':
    '계정, 언어, 테마 옵션을 보여 주는 PushupAI 설정 화면',
  'showcase.start': '한 번으로 시작',
  'showcase.recognize': '실시간 인식',
  'showcase.record': '기록 남기기',
  'ecosystem.eyebrow': '한 번의 운동에서 습관으로',
  'ecosystem.titleAria':
    '이번 운동을 기억하고 다음 운동으로 이어 가세요.',
  'ecosystem.titleLine1': '이번 운동을 기억하고,',
  'ecosystem.titleLine2': '다음 운동으로 이어 가세요.',
  'ecosystem.intro':
    '기록, 순위, 멤버십까지 하나의 계정이 모든 성장을 이어 줘요.',
  'ecosystem.recordKicker': '기록',
  'ecosystem.syncTitle': '휴대폰이 바뀌어도 성장은 그대로',
  'ecosystem.syncBody':
    'Premium 회원으로 로그인하면 운동 기록을 계속 이어 갈 수 있어요. 연결이 없어도 운동은 그대로 할 수 있습니다.',
  'ecosystem.synced': '동기화됨',
  'ecosystem.plazaKicker': '운동 광장',
  'ecosystem.rankingTitle': '함께 도전해요',
  'ecosystem.rankingBody':
    'Premium 회원은 일간·주간 순위에 참여해 익명의 공개 이름으로 오늘의 위치를 확인하고 다음 운동의 동기를 얻을 수 있어요.',
  'ecosystem.accountKicker': '계정',
  'ecosystem.accountTitle': '계정 하나로 계속 이어져요',
  'ecosystem.accountBody':
    'Google로 로그인하면 멤버십과 구매를 복원하고 앞으로 추가될 즐거움도 새 휴대폰에서 이어 갈 수 있어요.',
  'ecosystem.interfaceKicker': '인터페이스',
  'ecosystem.interfaceTitle': '내 방식에 맞게',
  'ecosystem.interfaceBody':
    '중국어 또는 영어, 라이트·다크·시스템 테마까지 PushupAI가 당신의 사용 습관에 맞춰져요.',
  'steps.eyebrow': '3단계로 시작',
  'steps.title': '휴대폰을 세우고 바로 시작하세요.',
  'steps.intro':
    '별도 장비도 복잡한 설정도 필요 없어요. 휴대폰 하나가 AI 운동 파트너가 됩니다.',
  'steps.fixTitle': '휴대폰 고정',
  'steps.fixBody': '휴대폰을 몸 앞에 두고 화면만 밝고 안정적으로 맞춰 주세요.',
  'steps.noticeTitle': '화면에 잘 보이는지 확인하세요',
  'steps.noticeBody': '머리, 어깨, 몸이 또렷하게 보이면 PushupAI도 준비 완료예요.',
  'steps.trainTitle': '운동에 집중',
  'steps.trainBody':
    '시작을 누르고 푸시업에 집중하세요. 카운트와 음성 안내는 PushupAI가 맡을게요.',
  'steps.scope':
    '지금은 표준 와이드 그립 푸시업에 집중해 한 번 한 번을 더 안정적으로 알아봐요.',
  'faq.eyebrow': '시작하기 전',
  'faq.title': '미리 알아두면 좋은 내용.',
  'faq.intro':
    '처음이어도 괜찮아요. 휴대폰 위치, 개인정보, 동작, 기록에 대해 여기서 쉽게 알려 드려요.',
  'faq.positionQuestion': '휴대폰은 어디에 두어야 하나요?',
  'faq.positionAnswer':
    '몸 정면에 고정하고 머리, 어깨, 몸통 전체가 보이게 하세요. 화면을 안정적이고 밝게 유지한 뒤 준비 자세 안내를 따르세요.',
  'faq.privacyQuestion': '영상이 업로드되나요?',
  'faq.privacyAnswerBefore':
    '원본 영상 프레임은 업로드되지 않습니다. 인식과 카운트는 기기 내에서 실행되고, 기록에는 횟수와 시간 같은 운동 데이터만 저장됩니다.',
  'faq.privacyPolicy': '개인정보 처리방침',
  'faq.privacyAnswerMiddle': '또는',
  'faq.accountDeletion': '계정 삭제 안내',
  'faq.privacyAnswerAfter': '를 확인하세요.',
  'faq.actionsQuestion': '어떤 운동을 지원하나요?',
  'faq.actionsAnswer':
    '현재 버전은 정면에 고정한 휴대폰으로 한 명이 하는 표준 와이드 그립 푸시업에 집중합니다. 근거리에서 팔꿈치나 손목이 잠시 안 보여도 허용하지만, 머리, 어깨, 몸통은 계속 보여야 합니다.',
  'faq.syncQuestion': '운동 기록은 어떻게 동기화하나요?',
  'faq.syncAnswer':
    '로컬 운동은 로그인 없이 사용할 수 있습니다. Premium 회원은 현재 계정의 기록을 동기화할 수 있고, 클라우드를 사용할 수 없을 때도 로컬 기록은 표시됩니다.',
  'faq.downloadQuestion': '언제 앱을 다운로드할 수 있나요?',
  'faq.downloadAnswer':
    'Google Play 0.3.4는 폐쇄형 Alpha 테스터에게 공개되었습니다. Android APK 0.3.4는 지금 직접 다운로드할 수 있으며, App Store 버전은 계속 준비 중입니다.',
  'download.eyebrow': 'PushupAI · AI 푸시업',
  'download.titleLine1': '다음 운동에서,',
  'download.titleLine2': '한 번의 동작도 놓치지 마세요.',
  'download.intro':
    'PushupAI는 첫 사용자들과 운동을 시작했어요. 더 많은 다운로드 방법이 곧 열립니다.',
  'apk.kicker': 'Android 사용자',
  'apk.title': '바로 다운로드',
  'apk.body': 'Android 휴대폰으로 코드를 스캔해 바로 설치할 수 있어요.',
  'apk.status': '0.3.4 다운로드 가능',
  'apk.placeholder': '0.3.4 · 317 MB',
  'apk.action': '설치 패키지 다운로드',
  'apk.qrLabel': '휴대폰으로 스캔',
  'apk.dialogTitle': 'Android 설치 패키지',
  'apk.dialogPrompt': 'Android APK 설치 패키지를 다운로드할까요?',
  'apk.unavailable': '설치 패키지를 준비 중입니다. 공개되면 여기에서 다운로드할 수 있어요.',
  'apk.confirm': '다운로드 계속',
  'apk.close': '닫기',
  'footer.top': '맨 위로',
  'footer.summary': '카운트는 AI에게. 꾸준함은 당신답게.',
  'footer.privacySummary': 'AI가 동작을 이해해요. 당신의 운동 영상은 오직 당신의 것.',
  'footer.linksLabel': '개인정보와 계정',
  'footer.privacyPolicy': '개인정보 처리방침',
  'footer.accountDeletion': '계정 삭제',
});

export const TRANSLATIONS = Object.freeze({
  'zh-CN': zhCN,
  en,
  es,
  fr,
  de,
  'pt-BR': ptBR,
  ja,
  ko,
});

export function normalizeLocale(value) {
  if (typeof value !== 'string' || value.trim() === '') {
    return null;
  }
  const candidate = value.trim();
  const exact = LOCALES.find(
    ({ code }) => code.toLowerCase() === candidate.toLowerCase(),
  );
  if (exact) {
    return exact.code;
  }
  return aliases[candidate.toLowerCase().split('-')[0]] ?? null;
}

export function resolveLocale({
  urlLocale,
  storedLocale,
  browserLocales = [],
} = {}) {
  for (const candidate of [urlLocale, storedLocale, ...browserLocales]) {
    const locale = normalizeLocale(candidate);
    if (locale) {
      return locale;
    }
  }
  return DEFAULT_LOCALE;
}

export function translate(locale, key) {
  const normalized = normalizeLocale(locale) ?? DEFAULT_LOCALE;
  return TRANSLATIONS[normalized]?.[key] ?? TRANSLATIONS.en[key] ?? '';
}

export function urlWithLocale(href, locale) {
  const url = new URL(href);
  url.searchParams.set('lang', normalizeLocale(locale) ?? DEFAULT_LOCALE);
  return url.href;
}
