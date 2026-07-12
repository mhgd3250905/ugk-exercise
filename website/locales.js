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
    'PushupAI 使用端侧 AI 实时识别俯卧撑动作，自动计数、中文语音播报并记录训练。',
  'meta.ogTitle': 'PushupAI · AI俯卧撑',
  'meta.ogDescription': '架好手机，专心做好每一次。端侧 AI 自动识别、计数与播报。',
  'meta.ogLocale': 'zh_CN',
  'skip.main': '跳到主要内容',
  'brand.home': 'PushupAI 首页',
  'brand.productName': 'AI俯卧撑',
  'menu.open': '打开导航',
  'nav.label': '主要导航',
  'nav.features': '产品能力',
  'nav.ecosystem': '产品生态',
  'nav.how': '使用方式',
  'nav.faq': '常见问题',
  'nav.download': '下载',
  'header.status': 'Alpha 封闭测试',
  'language.label': '选择语言',
  'hero.eyebrow': '你的 AI 俯卧撑教练',
  'hero.titleAria': '架好手机，专心做好每一次。',
  'hero.titleLine1': '架好手机，',
  'hero.titleLine2': '专心做好',
  'hero.titleLine3': '每一次。',
  'hero.lede': '端侧 AI 实时识别动作，自动计数、语音播报，并为你留下每一次训练。',
  'download.channelsLabel': '下载渠道',
  'store.googleStatus': 'Alpha 封闭测试',
  'store.appleStatus': '准备中',
  'store.available': '立即下载',
  'privacy.short': '姿态识别在设备端完成 · 原始视频帧不上传',
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
    'MoveNet 实时识别身体姿态，完整推回顶部时计数；近距离下压时肘腕短时离屏也能容错。',
  'features.privacyTitle': '训练留在你的设备',
  'features.privacyBody': '训练开始前会说明相机用途。推理在手机端完成，原始视频帧不上传。',
  'features.recordsTitle': '每次进步，都有记录',
  'features.recordsBody': '中文语音即时播报，周、月、年统计帮你看见稳定积累。',
  'showcase.eyebrow': '从开始到坚持',
  'showcase.title': '训练过程，清楚可见。',
  'showcase.intro': '简单的入口、醒目的计数、清晰的记录，每一屏都为训练服务。',
  'showcase.galleryLabel': 'App 页面展示',
  'showcase.homeAlt': 'AI俯卧撑首页，显示开始训练入口',
  'showcase.workoutAlt': 'AI俯卧撑训练页，显示实时姿态识别和计数',
  'showcase.recordsAlt': 'AI俯卧撑训练记录，显示周月年统计入口',
  'showcase.start': '一键开始',
  'showcase.recognize': '实时识别',
  'showcase.record': '留下记录',
  'ecosystem.eyebrow': '从训练到坚持',
  'ecosystem.titleAria': '不只记住这一次，也陪你坚持下一次。',
  'ecosystem.titleLine1': '不只记住这一次，',
  'ecosystem.titleLine2': '也陪你坚持下一次。',
  'ecosystem.intro': '训练先留在本机；需要时，再通过账号连接记录、权益和运动广场。',
  'ecosystem.recordKicker': '记录',
  'ecosystem.syncTitle': '训练记录与云端同步',
  'ecosystem.syncBody': '本地训练始终可用。登录 Premium 会员后，可同步归属当前账号的记录；云端暂不可用时，本地记录仍会显示。',
  'ecosystem.synced': '已同步',
  'ecosystem.plazaKicker': '运动广场',
  'ecosystem.rankingTitle': '日榜和周榜，看见自己的位置',
  'ecosystem.rankingBody': 'Premium 会员可选择加入俯卧撑排行，查看个人排名与完成次数；公开榜单采用匿名展示。',
  'ecosystem.accountKicker': '账号',
  'ecosystem.accountTitle': '一个账号，恢复权益',
  'ecosystem.accountBody': '使用 Google 账号登录，会员状态与后续高级能力归属当前账号，并支持恢复购买。',
  'ecosystem.interfaceKicker': '界面',
  'ecosystem.interfaceTitle': '跟随你的设备',
  'ecosystem.interfaceBody': 'App 界面当前支持中文和英文，也支持浅色、深色与跟随系统主题。',
  'steps.eyebrow': '三步开始',
  'steps.title': '架好，确认，开始。',
  'steps.intro': '不需要穿戴设备，也不需要复杂设置。一台手机，就是你的训练搭档。',
  'steps.fixTitle': '固定手机',
  'steps.fixBody': '将手机固定在身体正前方，保持画面稳定、光线充足。',
  'steps.noticeTitle': '确认端侧处理',
  'steps.noticeBody': '进入训练后，先确认相机画面仅用于本机姿态识别和计数。',
  'steps.trainTitle': '专心训练',
  'steps.trainBody': '让头肩和躯干保持入镜，准备完成后开始动作，计数与中文语音播报自动进行。',
  'steps.scope': '当前适用于单人、手机固定正前方的标准宽距俯卧撑。',
  'faq.eyebrow': '开始之前',
  'faq.title': '你可能还想知道。',
  'faq.intro': '关于摆放、隐私、动作范围和训练记录，这里给出当前产品的真实答案。',
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
  'faq.downloadAnswer': 'Google Play 正处于 Alpha 封闭测试阶段，App Store 版本正在准备，Android APK 直接下载入口也尚未开放。真实下载可用后，本页会启用对应入口。',
  'download.eyebrow': 'PushupAI · AI俯卧撑',
  'download.titleLine1': '下一次训练，',
  'download.titleLine2': '让每一下都有数。',
  'download.intro': 'Google Play 封闭测试中，App Store 和 Android APK 渠道正在准备。',
  'apk.kicker': 'Android 直接安装',
  'apk.title': 'Android APK',
  'apk.body': '未来可使用 Android 手机扫码下载并直接安装。',
  'apk.status': 'APK 即将提供',
  'apk.placeholder': '当前无可扫描下载',
  'footer.top': '回到页面顶部',
  'footer.summary': '端侧 AI 俯卧撑识别与计数。',
  'footer.privacySummary': '识别在设备端完成 · 原始视频帧不上传',
  'footer.linksLabel': '隐私与账号',
  'footer.privacyPolicy': '隐私政策',
  'footer.accountDeletion': '账号删除',
});

const en = Object.freeze({
  'meta.title': 'PushupAI · AI Push-Up Coach',
  'meta.description':
    'PushupAI uses on-device AI to recognize push-ups in real time, count reps, provide Chinese voice prompts, and record workouts.',
  'meta.ogTitle': 'PushupAI · AI Push-Up Coach',
  'meta.ogDescription':
    'Set up your phone and focus on every rep. On-device AI recognizes, counts, and announces your push-ups.',
  'meta.ogLocale': 'en_US',
  'skip.main': 'Skip to main content',
  'brand.home': 'PushupAI home',
  'brand.productName': 'AI Push-Up Coach',
  'menu.open': 'Open navigation',
  'nav.label': 'Primary navigation',
  'nav.features': 'Features',
  'nav.ecosystem': 'Ecosystem',
  'nav.how': 'How it works',
  'nav.faq': 'FAQ',
  'nav.download': 'Download',
  'header.status': 'Closed Alpha',
  'language.label': 'Choose language',
  'hero.eyebrow': 'Your AI push-up coach',
  'hero.titleAria': 'Set up your phone. Focus on every rep.',
  'hero.titleLine1': 'Set up your phone.',
  'hero.titleLine2': 'Focus on',
  'hero.titleLine3': 'every rep.',
  'hero.lede':
    'On-device AI recognizes your movement in real time, counts automatically, provides voice prompts, and records every workout.',
  'download.channelsLabel': 'Download channels',
  'store.googleStatus': 'Closed Alpha',
  'store.appleStatus': 'In preparation',
  'store.available': 'Download now',
  'privacy.short':
    'Pose recognition happens on-device · Original video frames are not uploaded',
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
    'MoveNet recognizes body pose in real time and counts after a full return to the top, while tolerating brief elbow, wrist, or arm dropouts at close range.',
  'features.privacyTitle': 'Your workout stays on your device',
  'features.privacyBody':
    'Before training starts, the app explains how the camera is used. Inference runs on your phone and original video frames are not uploaded.',
  'features.recordsTitle': 'Every improvement, recorded',
  'features.recordsBody':
    'Chinese voice prompts provide instant feedback, while week, month, and year views make consistency visible.',
  'showcase.eyebrow': 'From starting to staying consistent',
  'showcase.title': 'A clear view of every workout.',
  'showcase.intro':
    'A simple start, a bold counter, and clear records. Every screen serves the workout.',
  'showcase.galleryLabel': 'App screen gallery',
  'showcase.homeAlt': 'PushupAI home screen with the start workout action',
  'showcase.workoutAlt':
    'PushupAI workout screen with real-time pose recognition and counting',
  'showcase.recordsAlt':
    'PushupAI records screen with week, month, and year views',
  'showcase.start': 'Start in one tap',
  'showcase.recognize': 'Recognize in real time',
  'showcase.record': 'Keep the record',
  'ecosystem.eyebrow': 'From one workout to a lasting habit',
  'ecosystem.titleAria':
    'Remember this workout and help you return for the next one.',
  'ecosystem.titleLine1': 'Remember this workout.',
  'ecosystem.titleLine2': 'Return for the next one.',
  'ecosystem.intro':
    'Training stays local first. When you choose, your account connects records, benefits, and Sports Plaza.',
  'ecosystem.recordKicker': 'Records',
  'ecosystem.syncTitle': 'Workout records and cloud sync',
  'ecosystem.syncBody':
    'Local workouts always remain available. Signed-in Premium members can sync records owned by the current account; local records still appear when the cloud is unavailable.',
  'ecosystem.synced': 'Synced',
  'ecosystem.plazaKicker': 'Sports Plaza',
  'ecosystem.rankingTitle': 'Daily and weekly rankings',
  'ecosystem.rankingBody':
    'Premium members can choose to join push-up rankings and see their position and reps. Public rows use anonymous names.',
  'ecosystem.accountKicker': 'Account',
  'ecosystem.accountTitle': 'One account, restored benefits',
  'ecosystem.accountBody':
    'Sign in with Google. Membership status and future advanced features belong to the current account, with purchase restoration supported.',
  'ecosystem.interfaceKicker': 'Interface',
  'ecosystem.interfaceTitle': 'Follows your device',
  'ecosystem.interfaceBody':
    'The app interface currently supports Chinese and English, plus light, dark, and system theme modes.',
  'steps.eyebrow': 'Start in three steps',
  'steps.title': 'Set up. Confirm. Train.',
  'steps.intro':
    'No wearable and no complex setup. One phone is all you need for a training partner.',
  'steps.fixTitle': 'Fix your phone in place',
  'steps.fixBody':
    'Place your phone directly in front of your body. Keep the image stable and well lit.',
  'steps.noticeTitle': 'Confirm on-device processing',
  'steps.noticeBody':
    'After entering a workout, confirm that camera frames are used only on this device for pose recognition and counting.',
  'steps.trainTitle': 'Focus on training',
  'steps.trainBody':
    'Keep your head, shoulders, and torso in frame. Once ready, start moving and counting begins with Chinese voice prompts.',
  'steps.scope':
    'Currently designed for one person performing standard wide-grip push-ups with a fixed front-facing phone.',
  'faq.eyebrow': 'Before you begin',
  'faq.title': 'A few things you may want to know.',
  'faq.intro':
    'Straight answers about placement, privacy, supported movement, and workout records.',
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
    'Google Play is in Closed Alpha, the App Store version is in preparation, and direct Android APK downloads are not open yet. This page will activate each channel when a real download becomes available.',
  'download.eyebrow': 'PushupAI · AI Push-Up Coach',
  'download.titleLine1': 'For your next workout,',
  'download.titleLine2': 'make every rep count.',
  'download.intro':
    'Google Play is in Closed Alpha. App Store and Android APK channels are in preparation.',
  'apk.kicker': 'Direct Android install',
  'apk.title': 'Android APK',
  'apk.body':
    'In the future, scan with an Android phone to download and install directly.',
  'apk.status': 'APK coming soon',
  'apk.placeholder': 'No scannable download is available yet',
  'footer.top': 'Back to top',
  'footer.summary': 'On-device AI push-up recognition and counting.',
  'footer.privacySummary':
    'Recognition happens on-device · Original video frames are not uploaded',
  'footer.linksLabel': 'Privacy and account',
  'footer.privacyPolicy': 'Privacy Policy',
  'footer.accountDeletion': 'Account deletion',
});

const es = Object.freeze({
  'meta.title': 'PushupAI · Entrenador de flexiones con IA',
  'meta.description':
    'PushupAI usa IA en el dispositivo para reconocer flexiones en tiempo real, contar repeticiones, ofrecer avisos de voz en chino y registrar entrenamientos.',
  'meta.ogTitle': 'PushupAI · Entrenador de flexiones con IA',
  'meta.ogDescription':
    'Coloca el teléfono y concéntrate en cada repetición. La IA en el dispositivo reconoce, cuenta y anuncia tus flexiones.',
  'meta.ogLocale': 'es_ES',
  'skip.main': 'Saltar al contenido principal',
  'brand.home': 'Inicio de PushupAI',
  'brand.productName': 'Entrenador de flexiones con IA',
  'menu.open': 'Abrir navegación',
  'nav.label': 'Navegación principal',
  'nav.features': 'Funciones',
  'nav.ecosystem': 'Ecosistema',
  'nav.how': 'Cómo funciona',
  'nav.faq': 'Preguntas',
  'nav.download': 'Descargar',
  'header.status': 'Alfa cerrada',
  'language.label': 'Elegir idioma',
  'hero.eyebrow': 'Tu entrenador de flexiones con IA',
  'hero.titleAria': 'Coloca el teléfono. Concéntrate en cada repetición.',
  'hero.titleLine1': 'Coloca el teléfono.',
  'hero.titleLine2': 'Concéntrate en',
  'hero.titleLine3': 'cada repetición.',
  'hero.lede':
    'La IA en el dispositivo reconoce el movimiento en tiempo real, cuenta automáticamente, ofrece avisos de voz y registra cada entrenamiento.',
  'download.channelsLabel': 'Canales de descarga',
  'store.googleStatus': 'Alfa cerrada',
  'store.appleStatus': 'En preparación',
  'store.available': 'Descargar ahora',
  'privacy.short':
    'El reconocimiento ocurre en el dispositivo · Los fotogramas originales no se suben',
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
    'MoveNet reconoce la postura en tiempo real y cuenta al volver por completo arriba, tolerando pérdidas breves de codos, muñecas o brazos a corta distancia.',
  'features.privacyTitle': 'Tu entrenamiento se queda en tu dispositivo',
  'features.privacyBody':
    'Antes de empezar, la app explica el uso de la cámara. La inferencia se ejecuta en el teléfono y los fotogramas originales no se suben.',
  'features.recordsTitle': 'Cada mejora queda registrada',
  'features.recordsBody':
    'Los avisos de voz en chino dan información inmediata y las vistas semanal, mensual y anual muestran tu constancia.',
  'showcase.eyebrow': 'De empezar a mantener el hábito',
  'showcase.title': 'Cada entrenamiento, claramente visible.',
  'showcase.intro':
    'Un inicio sencillo, un contador destacado y registros claros. Cada pantalla sirve al entrenamiento.',
  'showcase.galleryLabel': 'Galería de pantallas de la app',
  'showcase.homeAlt': 'Inicio de PushupAI con la acción para entrenar',
  'showcase.workoutAlt':
    'Pantalla de entrenamiento con reconocimiento y conteo en tiempo real',
  'showcase.recordsAlt':
    'Registros de PushupAI con vistas semanal, mensual y anual',
  'showcase.start': 'Empieza con un toque',
  'showcase.recognize': 'Reconoce en tiempo real',
  'showcase.record': 'Guarda el registro',
  'ecosystem.eyebrow': 'De un entrenamiento a un hábito',
  'ecosystem.titleAria':
    'Recuerda este entrenamiento y vuelve para el siguiente.',
  'ecosystem.titleLine1': 'Recuerda este entrenamiento.',
  'ecosystem.titleLine2': 'Vuelve para el siguiente.',
  'ecosystem.intro':
    'El entrenamiento se guarda primero en local. Cuando quieras, tu cuenta conecta registros, ventajas y la Plaza deportiva.',
  'ecosystem.recordKicker': 'Registros',
  'ecosystem.syncTitle': 'Registros y sincronización en la nube',
  'ecosystem.syncBody':
    'Los entrenamientos locales siempre están disponibles. Los miembros Premium con sesión iniciada pueden sincronizar registros de la cuenta actual; los registros locales siguen visibles si la nube no está disponible.',
  'ecosystem.synced': 'Sincronizado',
  'ecosystem.plazaKicker': 'Plaza deportiva',
  'ecosystem.rankingTitle': 'Clasificaciones diarias y semanales',
  'ecosystem.rankingBody':
    'Los miembros Premium pueden unirse a la clasificación de flexiones y ver su puesto y repeticiones. Las filas públicas usan nombres anónimos.',
  'ecosystem.accountKicker': 'Cuenta',
  'ecosystem.accountTitle': 'Una cuenta, ventajas recuperadas',
  'ecosystem.accountBody':
    'Inicia sesión con Google. La membresía y futuras funciones avanzadas pertenecen a la cuenta actual y se pueden restaurar las compras.',
  'ecosystem.interfaceKicker': 'Interfaz',
  'ecosystem.interfaceTitle': 'Se adapta a tu dispositivo',
  'ecosystem.interfaceBody':
    'La interfaz de la app admite actualmente chino e inglés, además de temas claro, oscuro y del sistema.',
  'steps.eyebrow': 'Empieza en tres pasos',
  'steps.title': 'Coloca. Confirma. Entrena.',
  'steps.intro':
    'Sin wearable ni configuración compleja. Un teléfono es todo lo que necesitas.',
  'steps.fixTitle': 'Fija el teléfono',
  'steps.fixBody':
    'Colócalo directamente delante de tu cuerpo. Mantén la imagen estable y bien iluminada.',
  'steps.noticeTitle': 'Confirma el procesamiento local',
  'steps.noticeBody':
    'Al entrar al entrenamiento, confirma que la cámara se usa solo en este dispositivo para reconocer y contar.',
  'steps.trainTitle': 'Concéntrate en entrenar',
  'steps.trainBody':
    'Mantén cabeza, hombros y torso en cuadro. Al estar listo, empieza; el conteo y los avisos de voz en chino se activan automáticamente.',
  'steps.scope':
    'Diseñado actualmente para una persona haciendo flexiones estándar con agarre amplio y un teléfono fijo al frente.',
  'faq.eyebrow': 'Antes de empezar',
  'faq.title': 'Quizá también quieras saber esto.',
  'faq.intro':
    'Respuestas claras sobre colocación, privacidad, movimiento compatible y registros.',
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
    'Google Play está en Alfa cerrada, la versión para App Store está en preparación y la descarga directa del APK aún no está abierta. Esta página activará cada canal cuando exista una descarga real.',
  'download.eyebrow': 'PushupAI · Flexiones con IA',
  'download.titleLine1': 'En tu próximo entrenamiento,',
  'download.titleLine2': 'haz que cada repetición cuente.',
  'download.intro':
    'Google Play está en Alfa cerrada. App Store y Android APK están en preparación.',
  'apk.kicker': 'Instalación directa en Android',
  'apk.title': 'Android APK',
  'apk.body':
    'En el futuro podrás escanear con un Android para descargar e instalar directamente.',
  'apk.status': 'APK próximamente',
  'apk.placeholder': 'Todavía no hay una descarga escaneable',
  'footer.top': 'Volver arriba',
  'footer.summary': 'Reconocimiento y conteo de flexiones con IA local.',
  'footer.privacySummary':
    'El reconocimiento ocurre en el dispositivo · Los fotogramas originales no se suben',
  'footer.linksLabel': 'Privacidad y cuenta',
  'footer.privacyPolicy': 'Política de privacidad',
  'footer.accountDeletion': 'Eliminar cuenta',
});

const fr = Object.freeze({
  'meta.title': 'PushupAI · Coach de pompes par IA',
  'meta.description':
    'PushupAI utilise une IA sur l’appareil pour reconnaître les pompes en temps réel, compter les répétitions, donner des annonces vocales en chinois et enregistrer les séances.',
  'meta.ogTitle': 'PushupAI · Coach de pompes par IA',
  'meta.ogDescription':
    'Installez votre téléphone et concentrez-vous sur chaque répétition. L’IA locale reconnaît, compte et annonce vos pompes.',
  'meta.ogLocale': 'fr_FR',
  'skip.main': 'Aller au contenu principal',
  'brand.home': 'Accueil PushupAI',
  'brand.productName': 'Coach de pompes par IA',
  'menu.open': 'Ouvrir la navigation',
  'nav.label': 'Navigation principale',
  'nav.features': 'Fonctions',
  'nav.ecosystem': 'Écosystème',
  'nav.how': 'Fonctionnement',
  'nav.faq': 'Questions',
  'nav.download': 'Télécharger',
  'header.status': 'Alpha fermée',
  'language.label': 'Choisir la langue',
  'hero.eyebrow': 'Votre coach de pompes par IA',
  'hero.titleAria': 'Installez le téléphone. Concentrez-vous sur chaque répétition.',
  'hero.titleLine1': 'Installez le téléphone.',
  'hero.titleLine2': 'Concentrez-vous sur',
  'hero.titleLine3': 'chaque répétition.',
  'hero.lede':
    'L’IA sur l’appareil reconnaît vos mouvements en temps réel, compte automatiquement, donne des annonces vocales et enregistre chaque séance.',
  'download.channelsLabel': 'Canaux de téléchargement',
  'store.googleStatus': 'Alpha fermée',
  'store.appleStatus': 'En préparation',
  'store.available': 'Télécharger',
  'privacy.short':
    'Reconnaissance sur l’appareil · Les images vidéo originales ne sont pas envoyées',
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
    'MoveNet reconnaît la posture en temps réel et compte après un retour complet en haut, tout en tolérant de brèves pertes des coudes, poignets ou bras à courte distance.',
  'features.privacyTitle': 'Votre séance reste sur votre appareil',
  'features.privacyBody':
    'Avant la séance, l’app explique l’usage de la caméra. L’analyse s’effectue sur le téléphone et les images originales ne sont pas envoyées.',
  'features.recordsTitle': 'Chaque progrès est enregistré',
  'features.recordsBody':
    'Les annonces vocales en chinois donnent un retour immédiat, tandis que les vues semaine, mois et année montrent votre régularité.',
  'showcase.eyebrow': 'Du premier essai à la régularité',
  'showcase.title': 'Chaque séance, clairement visible.',
  'showcase.intro':
    'Un départ simple, un compteur lisible et des historiques clairs. Chaque écran sert l’entraînement.',
  'showcase.galleryLabel': 'Galerie des écrans de l’application',
  'showcase.homeAlt': 'Accueil PushupAI avec le bouton de démarrage',
  'showcase.workoutAlt':
    'Écran d’entraînement PushupAI avec reconnaissance et comptage en temps réel',
  'showcase.recordsAlt':
    'Historique PushupAI avec vues semaine, mois et année',
  'showcase.start': 'Démarrer en un geste',
  'showcase.recognize': 'Reconnaître en temps réel',
  'showcase.record': 'Garder une trace',
  'ecosystem.eyebrow': 'D’une séance à une habitude',
  'ecosystem.titleAria':
    'Gardez cette séance en mémoire et revenez pour la suivante.',
  'ecosystem.titleLine1': 'Gardez cette séance.',
  'ecosystem.titleLine2': 'Revenez pour la suivante.',
  'ecosystem.intro':
    'La séance reste d’abord locale. Quand vous le souhaitez, votre compte relie historique, avantages et Espace sportif.',
  'ecosystem.recordKicker': 'Historique',
  'ecosystem.syncTitle': 'Historique et synchronisation cloud',
  'ecosystem.syncBody':
    'Les séances locales restent toujours disponibles. Les membres Premium connectés peuvent synchroniser les données du compte actuel ; l’historique local reste visible si le cloud est indisponible.',
  'ecosystem.synced': 'Synchronisé',
  'ecosystem.plazaKicker': 'Espace sportif',
  'ecosystem.rankingTitle': 'Classements quotidiens et hebdomadaires',
  'ecosystem.rankingBody':
    'Les membres Premium peuvent rejoindre le classement des pompes et voir leur place et leurs répétitions. Les lignes publiques utilisent des noms anonymes.',
  'ecosystem.accountKicker': 'Compte',
  'ecosystem.accountTitle': 'Un compte, vos avantages retrouvés',
  'ecosystem.accountBody':
    'Connectez-vous avec Google. L’abonnement et les futures fonctions avancées appartiennent au compte actuel, avec restauration des achats.',
  'ecosystem.interfaceKicker': 'Interface',
  'ecosystem.interfaceTitle': 'S’adapte à votre appareil',
  'ecosystem.interfaceBody':
    'L’interface de l’app prend actuellement en charge le chinois et l’anglais, ainsi que les thèmes clair, sombre et système.',
  'steps.eyebrow': 'Commencez en trois étapes',
  'steps.title': 'Installez. Confirmez. Entraînez-vous.',
  'steps.intro':
    'Aucun objet connecté ni réglage complexe. Un téléphone suffit comme partenaire d’entraînement.',
  'steps.fixTitle': 'Fixez le téléphone',
  'steps.fixBody':
    'Placez-le directement face à votre corps. Gardez une image stable et bien éclairée.',
  'steps.noticeTitle': 'Confirmez le traitement local',
  'steps.noticeBody':
    'En entrant dans la séance, confirmez que la caméra sert uniquement à la reconnaissance et au comptage sur cet appareil.',
  'steps.trainTitle': 'Concentrez-vous sur l’effort',
  'steps.trainBody':
    'Gardez tête, épaules et torse dans l’image. Une fois prêt, commencez : le comptage et les annonces vocales en chinois démarrent automatiquement.',
  'steps.scope':
    'Conçu actuellement pour une personne effectuant des pompes standard à prise large avec un téléphone fixe de face.',
  'faq.eyebrow': 'Avant de commencer',
  'faq.title': 'Quelques réponses utiles.',
  'faq.intro':
    'Des réponses claires sur le placement, la confidentialité, le mouvement pris en charge et l’historique.',
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
    'Google Play est en Alpha fermée, la version App Store est en préparation et le téléchargement direct APK n’est pas encore ouvert. Cette page activera chaque canal lorsqu’un vrai téléchargement sera disponible.',
  'download.eyebrow': 'PushupAI · Pompes avec IA',
  'download.titleLine1': 'Pour votre prochaine séance,',
  'download.titleLine2': 'faites compter chaque répétition.',
  'download.intro':
    'Google Play est en Alpha fermée. App Store et Android APK sont en préparation.',
  'apk.kicker': 'Installation directe Android',
  'apk.title': 'Android APK',
  'apk.body':
    'Vous pourrez plus tard scanner avec un téléphone Android pour télécharger et installer directement.',
  'apk.status': 'APK bientôt disponible',
  'apk.placeholder': 'Aucun téléchargement à scanner pour le moment',
  'footer.top': 'Retour en haut',
  'footer.summary': 'Reconnaissance et comptage des pompes par IA locale.',
  'footer.privacySummary':
    'Reconnaissance sur l’appareil · Les images originales ne sont pas envoyées',
  'footer.linksLabel': 'Confidentialité et compte',
  'footer.privacyPolicy': 'Politique de confidentialité',
  'footer.accountDeletion': 'Supprimer le compte',
});

const de = Object.freeze({
  'meta.title': 'PushupAI · KI-Liegestütz-Coach',
  'meta.description':
    'PushupAI erkennt Liegestütze mit KI direkt auf dem Gerät, zählt Wiederholungen, gibt chinesische Sprachhinweise und zeichnet Trainings auf.',
  'meta.ogTitle': 'PushupAI · KI-Liegestütz-Coach',
  'meta.ogDescription':
    'Stelle dein Smartphone auf und konzentriere dich auf jede Wiederholung. Die KI auf dem Gerät erkennt, zählt und sagt deine Liegestütze an.',
  'meta.ogLocale': 'de_DE',
  'skip.main': 'Zum Hauptinhalt springen',
  'brand.home': 'PushupAI Startseite',
  'brand.productName': 'KI-Liegestütz-Coach',
  'menu.open': 'Navigation öffnen',
  'nav.label': 'Hauptnavigation',
  'nav.features': 'Funktionen',
  'nav.ecosystem': 'Ökosystem',
  'nav.how': 'So funktioniert es',
  'nav.faq': 'FAQ',
  'nav.download': 'Download',
  'header.status': 'Geschlossene Alpha',
  'language.label': 'Sprache wählen',
  'hero.eyebrow': 'Dein KI-Liegestütz-Coach',
  'hero.titleAria': 'Stelle dein Smartphone auf. Konzentriere dich auf jede Wiederholung.',
  'hero.titleLine1': 'Smartphone aufstellen.',
  'hero.titleLine2': 'Konzentriere dich auf',
  'hero.titleLine3': 'jede Wiederholung.',
  'hero.lede':
    'Die KI auf dem Gerät erkennt Bewegungen in Echtzeit, zählt automatisch, gibt Sprachhinweise und speichert jedes Training.',
  'download.channelsLabel': 'Download-Kanäle',
  'store.googleStatus': 'Geschlossene Alpha',
  'store.appleStatus': 'In Vorbereitung',
  'store.available': 'Jetzt herunterladen',
  'privacy.short':
    'Erkennung auf dem Gerät · Originale Videobilder werden nicht hochgeladen',
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
    'MoveNet erkennt die Körperhaltung in Echtzeit und zählt nach der vollständigen Rückkehr nach oben. Kurze Ausfälle von Ellbogen, Handgelenken oder Armen aus der Nähe werden toleriert.',
  'features.privacyTitle': 'Dein Training bleibt auf deinem Gerät',
  'features.privacyBody':
    'Vor dem Start erklärt die App die Kameranutzung. Die Analyse läuft auf dem Smartphone und originale Videobilder werden nicht hochgeladen.',
  'features.recordsTitle': 'Jeder Fortschritt wird festgehalten',
  'features.recordsBody':
    'Chinesische Sprachhinweise geben direktes Feedback; Wochen-, Monats- und Jahresansichten zeigen deine Beständigkeit.',
  'showcase.eyebrow': 'Vom Start zur Beständigkeit',
  'showcase.title': 'Jedes Training klar im Blick.',
  'showcase.intro':
    'Ein einfacher Start, ein gut sichtbarer Zähler und klare Aufzeichnungen. Jeder Bildschirm dient dem Training.',
  'showcase.galleryLabel': 'Galerie der App-Bildschirme',
  'showcase.homeAlt': 'PushupAI Startbildschirm mit Trainingsstart',
  'showcase.workoutAlt':
    'PushupAI Trainingsbildschirm mit Echtzeit-Erkennung und Zählung',
  'showcase.recordsAlt':
    'PushupAI Aufzeichnungen mit Wochen-, Monats- und Jahresansicht',
  'showcase.start': 'Mit einem Tippen starten',
  'showcase.recognize': 'In Echtzeit erkennen',
  'showcase.record': 'Fortschritt festhalten',
  'ecosystem.eyebrow': 'Vom Training zur Gewohnheit',
  'ecosystem.titleAria':
    'Dieses Training merken und zum nächsten zurückkehren.',
  'ecosystem.titleLine1': 'Dieses Training merken.',
  'ecosystem.titleLine2': 'Zum nächsten zurückkehren.',
  'ecosystem.intro':
    'Training bleibt zuerst lokal. Wenn du möchtest, verbindet dein Konto Aufzeichnungen, Vorteile und den Sportplatz.',
  'ecosystem.recordKicker': 'Aufzeichnungen',
  'ecosystem.syncTitle': 'Trainingsdaten und Cloud-Synchronisierung',
  'ecosystem.syncBody':
    'Lokale Trainings bleiben immer verfügbar. Angemeldete Premium-Mitglieder können Daten des aktuellen Kontos synchronisieren; lokale Aufzeichnungen bleiben auch ohne Cloud sichtbar.',
  'ecosystem.synced': 'Synchronisiert',
  'ecosystem.plazaKicker': 'Sportplatz',
  'ecosystem.rankingTitle': 'Tages- und Wochenranglisten',
  'ecosystem.rankingBody':
    'Premium-Mitglieder können der Liegestütz-Rangliste beitreten und Platz sowie Wiederholungen sehen. Öffentliche Zeilen verwenden anonyme Namen.',
  'ecosystem.accountKicker': 'Konto',
  'ecosystem.accountTitle': 'Ein Konto, wiederhergestellte Vorteile',
  'ecosystem.accountBody':
    'Mit Google anmelden. Mitgliedschaft und künftige erweiterte Funktionen gehören zum aktuellen Konto; Käufe können wiederhergestellt werden.',
  'ecosystem.interfaceKicker': 'Oberfläche',
  'ecosystem.interfaceTitle': 'Passt sich deinem Gerät an',
  'ecosystem.interfaceBody':
    'Die App-Oberfläche unterstützt derzeit Chinesisch und Englisch sowie helle, dunkle und systemabhängige Designs.',
  'steps.eyebrow': 'In drei Schritten starten',
  'steps.title': 'Aufstellen. Bestätigen. Trainieren.',
  'steps.intro':
    'Kein Wearable und keine komplizierte Einrichtung. Ein Smartphone genügt als Trainingspartner.',
  'steps.fixTitle': 'Smartphone fixieren',
  'steps.fixBody':
    'Stelle es direkt vor deinem Körper auf. Halte das Bild stabil und gut beleuchtet.',
  'steps.noticeTitle': 'Lokale Verarbeitung bestätigen',
  'steps.noticeBody':
    'Bestätige beim Trainingsstart, dass Kamerabilder nur auf diesem Gerät zur Pose-Erkennung und Zählung verwendet werden.',
  'steps.trainTitle': 'Auf das Training konzentrieren',
  'steps.trainBody':
    'Halte Kopf, Schultern und Oberkörper im Bild. Sobald du bereit bist, starten Zählung und chinesische Sprachhinweise automatisch.',
  'steps.scope':
    'Derzeit für eine Person bei Standard-Liegestützen mit breitem Griff und festem Smartphone von vorn ausgelegt.',
  'faq.eyebrow': 'Vor dem Start',
  'faq.title': 'Was du vielleicht noch wissen möchtest.',
  'faq.intro':
    'Klare Antworten zu Positionierung, Datenschutz, unterstützter Bewegung und Trainingsdaten.',
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
    'Google Play befindet sich in einer geschlossenen Alpha, die App-Store-Version ist in Vorbereitung und direkte APK-Downloads sind noch nicht geöffnet. Diese Seite aktiviert jeden Kanal, sobald ein echter Download verfügbar ist.',
  'download.eyebrow': 'PushupAI · KI-Liegestütze',
  'download.titleLine1': 'Beim nächsten Training',
  'download.titleLine2': 'zählt jede Wiederholung.',
  'download.intro':
    'Google Play ist in geschlossener Alpha. App Store und Android APK sind in Vorbereitung.',
  'apk.kicker': 'Direkte Android-Installation',
  'apk.title': 'Android APK',
  'apk.body':
    'Künftig kannst du mit einem Android-Smartphone scannen, herunterladen und direkt installieren.',
  'apk.status': 'APK demnächst verfügbar',
  'apk.placeholder': 'Noch kein scanbarer Download verfügbar',
  'footer.top': 'Nach oben',
  'footer.summary': 'KI-Liegestütz-Erkennung und Zählung auf dem Gerät.',
  'footer.privacySummary':
    'Erkennung auf dem Gerät · Originale Videobilder werden nicht hochgeladen',
  'footer.linksLabel': 'Datenschutz und Konto',
  'footer.privacyPolicy': 'Datenschutzerklärung',
  'footer.accountDeletion': 'Konto löschen',
});

const ptBR = Object.freeze({
  'meta.title': 'PushupAI · Treinador de flexões com IA',
  'meta.description':
    'PushupAI usa IA no dispositivo para reconhecer flexões em tempo real, contar repetições, oferecer avisos de voz em chinês e registrar treinos.',
  'meta.ogTitle': 'PushupAI · Treinador de flexões com IA',
  'meta.ogDescription':
    'Posicione o celular e foque em cada repetição. A IA no dispositivo reconhece, conta e anuncia suas flexões.',
  'meta.ogLocale': 'pt_BR',
  'skip.main': 'Ir para o conteúdo principal',
  'brand.home': 'Início do PushupAI',
  'brand.productName': 'Treinador de flexões com IA',
  'menu.open': 'Abrir navegação',
  'nav.label': 'Navegação principal',
  'nav.features': 'Recursos',
  'nav.ecosystem': 'Ecossistema',
  'nav.how': 'Como funciona',
  'nav.faq': 'Dúvidas',
  'nav.download': 'Baixar',
  'header.status': 'Alpha fechado',
  'language.label': 'Escolher idioma',
  'hero.eyebrow': 'Seu treinador de flexões com IA',
  'hero.titleAria': 'Posicione o celular. Foque em cada repetição.',
  'hero.titleLine1': 'Posicione o celular.',
  'hero.titleLine2': 'Foque em',
  'hero.titleLine3': 'cada repetição.',
  'hero.lede':
    'A IA no dispositivo reconhece o movimento em tempo real, conta automaticamente, oferece avisos de voz e registra cada treino.',
  'download.channelsLabel': 'Canais de download',
  'store.googleStatus': 'Alpha fechado',
  'store.appleStatus': 'Em preparação',
  'store.available': 'Baixar agora',
  'privacy.short':
    'Reconhecimento no dispositivo · Os quadros originais não são enviados',
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
    'O MoveNet reconhece a postura em tempo real e conta após o retorno completo ao topo, tolerando perdas breves de cotovelos, punhos ou braços a curta distância.',
  'features.privacyTitle': 'Seu treino fica no seu dispositivo',
  'features.privacyBody':
    'Antes do treino, o app explica o uso da câmera. A inferência roda no celular e os quadros originais não são enviados.',
  'features.recordsTitle': 'Cada progresso fica registrado',
  'features.recordsBody':
    'Avisos de voz em chinês dão retorno imediato, enquanto as visões semanal, mensal e anual mostram sua constância.',
  'showcase.eyebrow': 'Do começo à consistência',
  'showcase.title': 'Cada treino, claramente visível.',
  'showcase.intro':
    'Um início simples, um contador em destaque e registros claros. Cada tela serve ao treino.',
  'showcase.galleryLabel': 'Galeria de telas do app',
  'showcase.homeAlt': 'Tela inicial do PushupAI com a ação de iniciar treino',
  'showcase.workoutAlt':
    'Tela de treino do PushupAI com reconhecimento e contagem em tempo real',
  'showcase.recordsAlt':
    'Registros do PushupAI com visões semanal, mensal e anual',
  'showcase.start': 'Comece com um toque',
  'showcase.recognize': 'Reconheça em tempo real',
  'showcase.record': 'Guarde o registro',
  'ecosystem.eyebrow': 'De um treino a um hábito',
  'ecosystem.titleAria':
    'Lembre deste treino e volte para o próximo.',
  'ecosystem.titleLine1': 'Lembre deste treino.',
  'ecosystem.titleLine2': 'Volte para o próximo.',
  'ecosystem.intro':
    'O treino fica primeiro no aparelho. Quando quiser, sua conta conecta registros, benefícios e a Praça esportiva.',
  'ecosystem.recordKicker': 'Registros',
  'ecosystem.syncTitle': 'Registros e sincronização na nuvem',
  'ecosystem.syncBody':
    'Os treinos locais ficam sempre disponíveis. Membros Premium conectados podem sincronizar registros da conta atual; os dados locais continuam visíveis se a nuvem estiver indisponível.',
  'ecosystem.synced': 'Sincronizado',
  'ecosystem.plazaKicker': 'Praça esportiva',
  'ecosystem.rankingTitle': 'Rankings diário e semanal',
  'ecosystem.rankingBody':
    'Membros Premium podem entrar no ranking de flexões e ver posição e repetições. As linhas públicas usam nomes anônimos.',
  'ecosystem.accountKicker': 'Conta',
  'ecosystem.accountTitle': 'Uma conta, benefícios restaurados',
  'ecosystem.accountBody':
    'Entre com o Google. A assinatura e futuros recursos avançados pertencem à conta atual, com restauração de compras.',
  'ecosystem.interfaceKicker': 'Interface',
  'ecosystem.interfaceTitle': 'Acompanha seu dispositivo',
  'ecosystem.interfaceBody':
    'A interface do app atualmente oferece chinês e inglês, além dos temas claro, escuro e do sistema.',
  'steps.eyebrow': 'Comece em três passos',
  'steps.title': 'Posicione. Confirme. Treine.',
  'steps.intro':
    'Sem wearable e sem configuração complicada. Um celular basta como parceiro de treino.',
  'steps.fixTitle': 'Fixe o celular',
  'steps.fixBody':
    'Coloque-o diretamente à frente do corpo. Mantenha a imagem estável e bem iluminada.',
  'steps.noticeTitle': 'Confirme o processamento local',
  'steps.noticeBody':
    'Ao entrar no treino, confirme que a câmera é usada apenas neste dispositivo para reconhecer e contar.',
  'steps.trainTitle': 'Foque no treino',
  'steps.trainBody':
    'Mantenha cabeça, ombros e tronco no quadro. Quando estiver pronto, comece; a contagem e os avisos em chinês iniciam automaticamente.',
  'steps.scope':
    'Atualmente feito para uma pessoa realizando flexões padrão com pegada aberta e celular fixo de frente.',
  'faq.eyebrow': 'Antes de começar',
  'faq.title': 'Algumas coisas que você pode querer saber.',
  'faq.intro':
    'Respostas claras sobre posicionamento, privacidade, movimento compatível e registros.',
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
    'O Google Play está em Alpha fechado, a versão da App Store está em preparação e o download direto do APK ainda não foi aberto. Esta página ativará cada canal quando houver um download real.',
  'download.eyebrow': 'PushupAI · Flexões com IA',
  'download.titleLine1': 'No seu próximo treino,',
  'download.titleLine2': 'faça cada repetição contar.',
  'download.intro':
    'Google Play está em Alpha fechado. App Store e Android APK estão em preparação.',
  'apk.kicker': 'Instalação direta no Android',
  'apk.title': 'Android APK',
  'apk.body':
    'No futuro, escaneie com um Android para baixar e instalar diretamente.',
  'apk.status': 'APK em breve',
  'apk.placeholder': 'Ainda não há download escaneável',
  'footer.top': 'Voltar ao topo',
  'footer.summary': 'Reconhecimento e contagem de flexões com IA local.',
  'footer.privacySummary':
    'Reconhecimento no dispositivo · Os quadros originais não são enviados',
  'footer.linksLabel': 'Privacidade e conta',
  'footer.privacyPolicy': 'Política de Privacidade',
  'footer.accountDeletion': 'Excluir conta',
});

const ja = Object.freeze({
  'meta.title': 'PushupAI · AI腕立て伏せコーチ',
  'meta.description':
    'PushupAIはデバイス上のAIで腕立て伏せをリアルタイム認識し、回数を数え、中国語の音声通知とトレーニング記録を提供します。',
  'meta.ogTitle': 'PushupAI · AI腕立て伏せコーチ',
  'meta.ogDescription':
    'スマートフォンを固定し、1回ずつに集中。デバイス上のAIが認識・カウント・読み上げを行います。',
  'meta.ogLocale': 'ja_JP',
  'skip.main': 'メインコンテンツへ',
  'brand.home': 'PushupAI ホーム',
  'brand.productName': 'AI腕立て伏せコーチ',
  'menu.open': 'ナビゲーションを開く',
  'nav.label': 'メインナビゲーション',
  'nav.features': '機能',
  'nav.ecosystem': 'エコシステム',
  'nav.how': '使い方',
  'nav.faq': 'よくある質問',
  'nav.download': 'ダウンロード',
  'header.status': 'クローズドAlpha',
  'language.label': '言語を選択',
  'hero.eyebrow': 'あなたのAI腕立て伏せコーチ',
  'hero.titleAria': 'スマートフォンを固定し、1回ずつに集中。',
  'hero.titleLine1': 'スマートフォンを固定。',
  'hero.titleLine2': '1回ずつに',
  'hero.titleLine3': '集中。',
  'hero.lede':
    'デバイス上のAIが動きをリアルタイムで認識し、自動カウント、音声通知、トレーニング記録を行います。',
  'download.channelsLabel': 'ダウンロード方法',
  'store.googleStatus': 'クローズドAlpha',
  'store.appleStatus': '準備中',
  'store.available': '今すぐダウンロード',
  'privacy.short':
    '認識はデバイス上で実行 · 元の映像フレームは送信しません',
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
    'MoveNetが姿勢をリアルタイム認識し、上位置へ完全に戻った時点で数えます。近距離で肘・手首・腕が短時間見えなくても許容します。',
  'features.privacyTitle': 'トレーニングはデバイス内に',
  'features.privacyBody':
    '開始前にカメラの用途を説明します。推論はスマートフォン上で行われ、元の映像フレームは送信しません。',
  'features.recordsTitle': 'すべての進歩を記録',
  'features.recordsBody':
    '中国語の音声通知ですぐに確認でき、週・月・年の表示で継続を見渡せます。',
  'showcase.eyebrow': '始めるから続けるまで',
  'showcase.title': 'トレーニングの流れを明確に。',
  'showcase.intro':
    'シンプルな開始、大きなカウンター、見やすい記録。すべての画面がトレーニングのためにあります。',
  'showcase.galleryLabel': 'アプリ画面ギャラリー',
  'showcase.homeAlt': 'トレーニング開始ボタンのあるPushupAIホーム画面',
  'showcase.workoutAlt':
    'リアルタイム姿勢認識とカウントを表示するPushupAIトレーニング画面',
  'showcase.recordsAlt':
    '週・月・年の表示を持つPushupAI記録画面',
  'showcase.start': '1タップで開始',
  'showcase.recognize': 'リアルタイム認識',
  'showcase.record': '記録を残す',
  'ecosystem.eyebrow': '1回のトレーニングから習慣へ',
  'ecosystem.titleAria':
    '今回を記録し、次回のトレーニングにつなげます。',
  'ecosystem.titleLine1': '今回を記録。',
  'ecosystem.titleLine2': '次回も続けられる。',
  'ecosystem.intro':
    'まずトレーニングは端末に保存。必要なときにアカウントが記録、特典、スポーツ広場をつなぎます。',
  'ecosystem.recordKicker': '記録',
  'ecosystem.syncTitle': 'トレーニング記録とクラウド同期',
  'ecosystem.syncBody':
    'ローカル記録は常に利用できます。ログインしたPremium会員は現在のアカウントの記録を同期でき、クラウドが使えないときもローカル記録は表示されます。',
  'ecosystem.synced': '同期済み',
  'ecosystem.plazaKicker': 'スポーツ広場',
  'ecosystem.rankingTitle': 'デイリーと週間ランキング',
  'ecosystem.rankingBody':
    'Premium会員は腕立て伏せランキングに参加し、順位と回数を確認できます。公開行は匿名で表示されます。',
  'ecosystem.accountKicker': 'アカウント',
  'ecosystem.accountTitle': '1つのアカウントで特典を復元',
  'ecosystem.accountBody':
    'Googleでログイン。会員状態と今後の高度機能は現在のアカウントに紐づき、購入の復元に対応します。',
  'ecosystem.interfaceKicker': 'インターフェース',
  'ecosystem.interfaceTitle': 'デバイスに合わせる',
  'ecosystem.interfaceBody':
    'アプリの画面は現在、中国語と英語に対応し、ライト、ダーク、システム設定のテーマを選べます。',
  'steps.eyebrow': '3ステップで開始',
  'steps.title': '固定。確認。トレーニング。',
  'steps.intro':
    'ウェアラブルも複雑な設定も不要。スマートフォン1台がトレーニングパートナーです。',
  'steps.fixTitle': 'スマートフォンを固定',
  'steps.fixBody':
    '体の正面に固定し、映像を安定させ、十分な明るさを確保します。',
  'steps.noticeTitle': 'デバイス上の処理を確認',
  'steps.noticeBody':
    'トレーニング開始時に、カメラ映像がこのデバイス上の姿勢認識とカウントのみに使われることを確認します。',
  'steps.trainTitle': 'トレーニングに集中',
  'steps.trainBody':
    '頭、肩、胴体を画面内に保ちます。準備が整ったら開始し、カウントと中国語の音声通知は自動で行われます。',
  'steps.scope':
    '現在は、正面に固定したスマートフォンで、1人が行う標準的なワイドスタンスの腕立て伏せに対応しています。',
  'faq.eyebrow': '始める前に',
  'faq.title': '知っておきたいこと。',
  'faq.intro':
    '設置、プライバシー、対応動作、トレーニング記録について明確に答えます。',
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
    'Google PlayはクローズドAlpha中、App Store版は準備中で、Android APKの直接ダウンロードもまだ開放されていません。実際のダウンロードが可能になり次第、このページで有効にします。',
  'download.eyebrow': 'PushupAI · AI腕立て伏せ',
  'download.titleLine1': '次のトレーニングで、',
  'download.titleLine2': '1回ずつを大切に。',
  'download.intro':
    'Google PlayはクローズドAlpha中。App StoreとAndroid APKは準備中です。',
  'apk.kicker': 'Android直接インストール',
  'apk.title': 'Android APK',
  'apk.body':
    '将来はAndroidスマートフォンでスキャンし、直接ダウンロードとインストールができます。',
  'apk.status': 'APKは近日提供',
  'apk.placeholder': '現在、スキャン可能なダウンロードはありません',
  'footer.top': 'ページ上部へ',
  'footer.summary': 'デバイス上のAI腕立て伏せ認識とカウント。',
  'footer.privacySummary':
    '認識はデバイス上で実行 · 元の映像フレームは送信しません',
  'footer.linksLabel': 'プライバシーとアカウント',
  'footer.privacyPolicy': 'プライバシーポリシー',
  'footer.accountDeletion': 'アカウント削除',
});

const ko = Object.freeze({
  'meta.title': 'PushupAI · AI 푸시업 코치',
  'meta.description':
    'PushupAI는 기기 내 AI로 푸시업을 실시간 인식하고 횟수를 세며, 중국어 음성 안내와 운동 기록을 제공합니다.',
  'meta.ogTitle': 'PushupAI · AI 푸시업 코치',
  'meta.ogDescription':
    '휴대폰을 고정하고 한 번의 동작에 집중하세요. 기기 내 AI가 푸시업을 인식하고 세며 알려줍니다.',
  'meta.ogLocale': 'ko_KR',
  'skip.main': '본문으로 바로가기',
  'brand.home': 'PushupAI 홈',
  'brand.productName': 'AI 푸시업 코치',
  'menu.open': '탐색 메뉴 열기',
  'nav.label': '주요 탐색',
  'nav.features': '주요 기능',
  'nav.ecosystem': '에코시스템',
  'nav.how': '사용 방법',
  'nav.faq': '자주 묻는 질문',
  'nav.download': '다운로드',
  'header.status': '폐쇄형 Alpha',
  'language.label': '언어 선택',
  'hero.eyebrow': '나만의 AI 푸시업 코치',
  'hero.titleAria': '휴대폰을 고정하고 한 번의 동작에 집중하세요.',
  'hero.titleLine1': '휴대폰을 고정하고,',
  'hero.titleLine2': '한 번의 동작에',
  'hero.titleLine3': '집중하세요.',
  'hero.lede':
    '기기 내 AI가 동작을 실시간 인식하고 자동 카운트, 음성 안내, 운동 기록을 제공합니다.',
  'download.channelsLabel': '다운로드 경로',
  'store.googleStatus': '폐쇄형 Alpha',
  'store.appleStatus': '준비 중',
  'store.available': '지금 다운로드',
  'privacy.short':
    '인식은 기기 내에서 수행 · 원본 영상 프레임은 업로드되지 않음',
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
    'MoveNet이 자세를 실시간 인식하고 정상 위치로 완전히 돌아오면 카운트합니다. 근거리에서 팔꿈치, 손목, 팔이 잠시 안 보여도 허용합니다.',
  'features.privacyTitle': '운동은 기기 안에만',
  'features.privacyBody':
    '운동 시작 전 앱이 카메라 용도를 안내합니다. 추론은 휴대폰에서 실행되며 원본 영상 프레임은 업로드되지 않습니다.',
  'features.recordsTitle': '모든 발전을 기록',
  'features.recordsBody':
    '중국어 음성 안내로 즉시 확인하고, 주간·월간·연간 보기로 꾸준함을 확인하세요.',
  'showcase.eyebrow': '시작에서 꾸준함까지',
  'showcase.title': '운동 과정을 명확하게.',
  'showcase.intro':
    '간단한 시작, 뚜렷한 카운터, 명확한 기록. 모든 화면이 운동을 위해 설계되었습니다.',
  'showcase.galleryLabel': '앱 화면 갤러리',
  'showcase.homeAlt': '운동 시작 버튼이 있는 PushupAI 홈 화면',
  'showcase.workoutAlt':
    '실시간 자세 인식과 카운트를 보여 주는 PushupAI 운동 화면',
  'showcase.recordsAlt':
    '주간·월간·연간 보기가 있는 PushupAI 기록 화면',
  'showcase.start': '한 번으로 시작',
  'showcase.recognize': '실시간 인식',
  'showcase.record': '기록 남기기',
  'ecosystem.eyebrow': '한 번의 운동에서 습관으로',
  'ecosystem.titleAria':
    '이번 운동을 기억하고 다음 운동으로 이어 가세요.',
  'ecosystem.titleLine1': '이번 운동을 기억하고,',
  'ecosystem.titleLine2': '다음 운동으로 이어 가세요.',
  'ecosystem.intro':
    '운동은 먼저 로컬에 저장됩니다. 원할 때 계정이 기록, 혜택, 운동 광장을 연결합니다.',
  'ecosystem.recordKicker': '기록',
  'ecosystem.syncTitle': '운동 기록과 클라우드 동기화',
  'ecosystem.syncBody':
    '로컬 운동은 항상 사용할 수 있습니다. 로그인한 Premium 회원은 현재 계정의 기록을 동기화할 수 있고, 클라우드를 사용할 수 없을 때도 로컬 기록은 표시됩니다.',
  'ecosystem.synced': '동기화됨',
  'ecosystem.plazaKicker': '운동 광장',
  'ecosystem.rankingTitle': '일간과 주간 순위',
  'ecosystem.rankingBody':
    'Premium 회원은 푸시업 순위에 선택적으로 참여해 순위와 횟수를 확인할 수 있습니다. 공개 행은 익명으로 표시됩니다.',
  'ecosystem.accountKicker': '계정',
  'ecosystem.accountTitle': '하나의 계정, 복원되는 혜택',
  'ecosystem.accountBody':
    'Google로 로그인하세요. 멤버십과 향후 고급 기능은 현재 계정에 귀속되며 구매 복원을 지원합니다.',
  'ecosystem.interfaceKicker': '인터페이스',
  'ecosystem.interfaceTitle': '기기에 맞춰서',
  'ecosystem.interfaceBody':
    '앱 인터페이스는 현재 중국어와 영어를 지원하며, 라이트·다크·시스템 테마를 제공합니다.',
  'steps.eyebrow': '3단계로 시작',
  'steps.title': '고정. 확인. 운동.',
  'steps.intro':
    '웨어러블도 복잡한 설정도 필요 없습니다. 휴대폰 하나면 충분합니다.',
  'steps.fixTitle': '휴대폰 고정',
  'steps.fixBody':
    '몸 정면에 고정하고 화면을 안정적이고 밝게 유지하세요.',
  'steps.noticeTitle': '기기 내 처리 확인',
  'steps.noticeBody':
    '운동에 진입한 뒤 카메라 화면이 이 기기의 자세 인식과 카운트에만 사용됨을 확인하세요.',
  'steps.trainTitle': '운동에 집중',
  'steps.trainBody':
    '머리, 어깨, 못통을 화면 안에 유지하세요. 준비가 되면 시작하고, 카운트와 중국어 음성 안내는 자동으로 진행됩니다.',
  'steps.scope':
    '현재는 정면에 고정한 휴대폰으로 한 명이 수행하는 표준 와이드 그립 푸시업에 맞춰져 있습니다.',
  'faq.eyebrow': '시작하기 전',
  'faq.title': '미리 알아두면 좋은 내용.',
  'faq.intro':
    '배치, 개인정보, 지원 동작, 운동 기록에 대한 명확한 답변입니다.',
  'faq.positionQuestion': '휴대폰은 어디에 두어야 하나요?',
  'faq.positionAnswer':
    '몸 정면에 고정하고 머리, 어깨, 못통 전체가 보이게 하세요. 화면을 안정적이고 밝게 유지한 뒤 준비 자세 안내를 따르세요.',
  'faq.privacyQuestion': '영상이 업로드되나요?',
  'faq.privacyAnswerBefore':
    '원본 영상 프레임은 업로드되지 않습니다. 인식과 카운트는 기기 내에서 실행되고, 기록에는 횟수와 시간 같은 운동 데이터만 저장됩니다.',
  'faq.privacyPolicy': '개인정보 처리방침',
  'faq.privacyAnswerMiddle': '또는',
  'faq.accountDeletion': '계정 삭제 안내',
  'faq.privacyAnswerAfter': '를 확인하세요.',
  'faq.actionsQuestion': '어떤 운동을 지원하나요?',
  'faq.actionsAnswer':
    '현재 버전은 정면에 고정한 휴대폰으로 한 명이 하는 표준 와이드 그립 푸시업에 집중합니다. 근거리에서 팔꿈치나 손목이 잠시 안 보여도 허용하지만, 머리, 어깨, 못통은 계속 보여야 합니다.',
  'faq.syncQuestion': '운동 기록은 어떻게 동기화하나요?',
  'faq.syncAnswer':
    '로컬 운동은 로그인 없이 사용할 수 있습니다. Premium 회원은 현재 계정의 기록을 동기화할 수 있고, 클라우드를 사용할 수 없을 때도 로컬 기록은 표시됩니다.',
  'faq.downloadQuestion': '언제 앱을 다운로드할 수 있나요?',
  'faq.downloadAnswer':
    'Google Play는 폐쇄형 Alpha 단계이고 App Store 버전은 준비 중이며, Android APK 직접 다운로드도 아직 열리지 않았습니다. 실제 다운로드가 준비되면 이 페이지에서 각 경로를 활성화합니다.',
  'download.eyebrow': 'PushupAI · AI 푸시업',
  'download.titleLine1': '다음 운동에서,',
  'download.titleLine2': '한 번의 동작도 놓치지 마세요.',
  'download.intro':
    'Google Play는 폐쇄형 Alpha 중입니다. App Store와 Android APK는 준비 중입니다.',
  'apk.kicker': 'Android 직접 설치',
  'apk.title': 'Android APK',
  'apk.body':
    '향후 Android 휴대폰으로 스캔해 직접 다운로드하고 설치할 수 있습니다.',
  'apk.status': 'APK 준비 중',
  'apk.placeholder': '현재 스캔 가능한 다운로드가 없습니다',
  'footer.top': '맨 위로',
  'footer.summary': '기기 내 AI 푸시업 인식과 카운트.',
  'footer.privacySummary':
    '인식은 기기 내에서 수행 · 원본 영상 프레임은 업로드되지 않음',
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
