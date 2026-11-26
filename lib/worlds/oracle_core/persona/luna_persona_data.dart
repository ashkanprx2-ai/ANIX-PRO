/// LUNA personality — the second NEXORA companion (warm, bubbly, playful, feminine). Same JSON shape as
/// [kOraclePersonaDefaults] so the same engine, admin editor and Supabase row format serve both companions
/// (`nx_oracle_persona` row 2). `{jan}` renders LUNA's stretched signature «عزییییزم» (see `signature`).
///
/// LUNA knows the same community players as ORACLE (their verified lines are shared, never invented); her own
/// voice lives in the greetings, reactions, tutorials, tours and replies below.
library;

import 'oracle_persona_data.dart';

final Map<String, dynamic> kLunaPersonaDefaults = <String, dynamic>{
  'version': 1,
  'companion': 'luna',
  'enabled': <String, dynamic>{
    'players': true,
    'greetings': true,
    'spontaneous': true,
    'results': true,
    'tutorials': true,
    'jan': true,
    'tour': true,
  },
  'freq': <String, dynamic>{
    'login_greeting_chance': 0.6,
    'login_original_joke_chance': 0.35,
    'spontaneous_global_gap_sec': 45,
    'spontaneous_category_gap_sec': 160,
    'spontaneous_chance': 0.5,
    'jan_chance': 0.7,
    'tutorial_auto_views': 2,
    'result_chance': 0.9,
    'margin_big': 3,
  },
  // «عزییییزم» — stem + stretched letter + tail; the short «عزیزم» in a line is upgraded automatically.
  'signature': <String, dynamic>{'stem': 'عزی', 'letter': 'ی', 'tail': 'زم', 'short': 'عزیزم'},
  'jan_stretch': <String, dynamic>{'min': 3, 'max': 6, 'base': 4},
  'unknown_player': '{jan} این یکی رو هنوز نمی‌شناسم! یه کم ازش برام تعریف کن؟ 💜',
  'ambiguous_player': 'وای کدومشون؟ {names} 🤔',
  'jan_wait': 'جونم؟ 💜',
  'players': kOraclePersonaDefaults['players'],
  'login_greetings': <List<String>>[
    <String>['اِ! اورجینال اومد؟! 😍', 'وایسا ببینم... نه، تویی! 🙈', 'ولی تو هم خیلی خوش اومدی {jan}!'],
    <String>['{jan} بالاخره اومدی! 💜', 'اوراکل می‌گفت اورجینال برمی‌گرده...', 'ولی من می‌دونستم تو میای!'],
  ],
  'login_self_original': <List<String>>[
    <String>['اورجینال! خودتی؟! 😍', 'سلطان تله‌ها برگشت! همه حواستون باشه! 💜'],
  ],
  'login_plain': <String>[
    'سلام {name} {jan}! دلم برات تنگ شده بود 💜',
    '{name} اومد! امروز چی بازی کنیم؟ 🎮',
    'به‌به {name}! امروز روز توئه، حسش می‌کنم ✨',
    'خوش برگشتی {name}! یه چای بریزم یا مستقیم بریم بازی؟ ☕',
  ],
  'spontaneous': <String, dynamic>{
    'enter': <String>['{jan} خوش اومدی! همه‌چی رو برات مرتب کردم 💜', 'اینجا امروز حس خوبی داره، نه؟ ✨'],
    'waiting': <String>['منتظر کی هستیم؟ بیا یه دست با من تمرین کن! 🎮', 'یه بازی کوچولو بزنیم تا بقیه برسن؟'],
    'match': <String>['تو می‌تونی {jan}! من تشویقت می‌کنم 📣', 'نفس عمیق، تمرکز، بزن بریم! 💪'],
    'idle': <String>['الو؟ هنوز اینجایی؟ 🥺', 'خوابت برد؟ من بیدارم‌ها! 🌙'],
    'funny': <String>['من و اوراکل شرط بستیم امروز ببری... من سمت توام! 😌', 'یه راز: اوراکل از عنکبوت می‌ترسه 🤫🕷️'],
    'unexpected': <String>['وای! این دیگه چی بود؟! 😮', 'اِ! انتظارشو نداشتم! 🙊'],
    'tease': <String>['اینجوری نگام نکن، خجالت می‌کشم 🙈', '{jan} یه لبخند بزن، قیافه‌ی جدی بهت نمیاد 😄'],
  },
  'results': <String, dynamic>{
    'lose': <String>[
      'اشکال نداره {jan}، دفعه‌ی بعد مال توئه 💜',
      'باخت فقط یعنی داری یاد می‌گیری! بیا دوباره 🌱',
      'من هنوزم فکر می‌کنم تو بهترینی 😌',
      'اوراکل الان داره می‌خنده... بیا با یه برد ساکتش کنیم! 😤',
    ],
    'win': <String>[
      'آفرین {jan}! می‌دونستم می‌تونی! 🎉',
      'وای چه بازی‌ای! دلم می‌خواد تشویقت کنم 📣',
      'این برد رو قاب می‌گیرم و می‌زنم به دیوار اتاقم 🖼️',
      'قهرمان من! 👑',
    ],
    'bad': <String>['آروم باش عزیزم، یه نفس عمیق... هنوز تموم نشده 🌸', 'بیا یه کم استراحت کنیم، بعد دوباره 💜'],
    'great': <String>[
      '{jan} {score}؟! این دیگه شاهکار بود! ✨',
      '{score}! حریفت الان داره به مامانش زنگ می‌زنه 😂',
    ],
    'draw': <String>['مساوی! یعنی هردوتون عالی بودین 🤝', 'نه بردی نه باختی، ولی دلم برات غنج رفت 💜'],
  },
  'tutorials': <String, dynamic>{
    'finger_soccer': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'basic', 'title': 'شوت زدن',
        'line': '{jan} مهره‌ی خودتو آروم بکش عقب و ول کن، مثل کش‌سان! 🎯',
        'how': 'یکی از مهره‌های خودت رو بکش و رها کن؛ هرچی بیشتر بکشی ضربه محکم‌تره. وقتی همه‌چی ایستاد نوبت عوض می‌شه.',
      },
      <String, dynamic>{
        'id': 'ice', 'title': 'ضربه‌ی نرم',
        'line': 'گاهی آروم‌تر یعنی دقیق‌تر، باور کن! ❄️',
        'how': 'کم بکش تا ضربه آروم و دقیق باشه؛ مهره رو آروم به توپ برسون و زاویه رو با جهت کشیدن تنظیم کن.',
      },
      <String, dynamic>{
        'id': 'power', 'title': 'ضربه‌ی قدرتی',
        'line': 'حالا وقتشه همه‌ی زورتو بزنی! 💥',
        'how': 'تا آخر بکش تا ضربه‌ی کامل بزنی؛ ولی حواست باشه بعد از شوت محکم، مهره‌ها خیلی جابه‌جا می‌شن.',
      },
      <String, dynamic>{
        'id': 'golden', 'title': 'گل طلایی',
        'line': 'مساوی شد؟ گل طلایی داریم! اولین گل، برنده‌ست ✨',
        'how': 'هر بازی ۵ دقیقه‌ست و تو تساوی، اولین گل (گل طلایی) برنده رو مشخص می‌کنه.',
      },
    ],
    'carrom': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'basic', 'title': 'استرایکر',
        'line': 'استرایکر رو بذار رو خط، نشونه بگیر و با ناز بزن! 🎯',
        'how': 'استرایکر رو روی خط پایه جابه‌جا کن، نشونه بگیر و ضربه بزن. انداختن مهره‌ی خودت یعنی نوبت دوباره.',
      },
      <String, dynamic>{
        'id': 'queen', 'title': 'ملکه',
        'line': 'ملکه‌ی قرمز رو انداختی؟ زود بپوشونش، ملکه‌ها تنهایی دوست ندارن 👑',
        'how': 'بعد از انداختن ملکه باید همون موقع یکی از مهره‌های خودت رو هم بندازی (پوشش). انداختن استرایکر خطاست.',
      },
    ],
    'billiards': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'basic', 'title': 'بریک و گروه',
        'line': 'اولین توپی که بندازی گروهت رو تعیین می‌کنه، پس قشنگ انتخاب کن 🎱',
        'how': 'بعد از بریک، اولین توپی که بندازی (ساده یا راه‌راه) گروه تو می‌شه. همه‌ی گروهت رو بنداز، بعد توپ ۸.',
      },
      <String, dynamic>{
        'id': 'foul', 'title': 'خطا',
        'line': 'مواظب توپ سفید باش عزیزم، اون نباید بیفته! 🙊',
        'how': 'افتادن سفید یا اول زدن به توپ اشتباه = توپ در دست حریف. توپ ۸ زودتر از موعد یا همراه سفید = باخت.',
      },
    ],
    'backgammon': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'basic', 'title': 'تاس و حرکت',
        'line': 'تاس بنداز و مهره‌ها رو ببر خونه؛ جفت آوردی؟ چهار حرکت! 🎲',
        'how': 'به اندازه‌ی هر تاس یه مهره جلو ببر؛ جفت یعنی چهار حرکت. مهره‌ی تنها رو می‌شه زد و فرستاد بار.',
      },
      <String, dynamic>{
        'id': 'bear', 'title': 'برداشتن',
        'line': 'همه رسیدن خونه؟ حالا یکی‌یکی جمعشون کن 🏡',
        'how': 'وقتی همه‌ی مهره‌ها تو خونه‌ی خودتن، شروع کن به برداشتن. اول کسی که همه رو برداره برنده‌ست.',
      },
    ],
    'ludo': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'basic', 'title': 'شش بیار',
        'line': 'برای بیرون اومدن باید شش بیاری؛ من برات دعا می‌کنم 🤞',
        'how': 'با ۶ مهره از پایگاه بیرون میاد و یه نوبت اضافه داری (سه تا ۶ پشت هم نوبت رو می‌سوزونه). خونه‌های ستاره‌دار امنن.',
      },
    ],
    'snakes_ladders': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'basic', 'title': 'مار و پله',
        'line': 'پله‌ها دوستتن، مارها... خب، اونا رو نادیده بگیر 🐍',
        'how': 'تاس بنداز و جلو برو؛ پای پل نور بالا می‌ری و رو سر مار پایین. برای ۱۰۰ عدد دقیق لازمه؛ ۶ یعنی نوبت دوباره.',
      },
    ],
    'uno': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'basic', 'title': 'NX!',
        'line': 'یه کارت موند؟ یادت نره بگی NX! وگرنه جریمه می‌شی 🙈',
        'how': 'کارتی بازی کن که رنگ، عدد یا نمادش با کارت وسط یکی باشه. با یه کارت باقی‌مونده دکمه‌ی NX! رو بزن.',
      },
    ],
    'quiz': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'basic', 'title': 'سرعت',
        'line': 'زود جواب بده ولی هول نشو؛ من بهت ایمان دارم 🧠',
        'how': '۱۰ سؤال، هر کدوم ۱۵ ثانیه. جواب درست امتیاز داره و سرعت جایزه‌ی اضافه.',
      },
    ],
    'mafia': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'basic', 'title': 'مافیا',
        'line': 'شب‌ها چشم‌ها بسته، روزها گوش‌ها باز! من به همه مشکوکم 🕵️‍♀️',
        'how': 'شهروندها باید مافیا رو پیدا کنن؛ مافیا شب‌ها یه نفر رو حذف می‌کنه. پزشک نجات می‌ده، کارآگاه استعلام می‌گیره. روزها بحث و رأی‌گیری.',
      },
    ],
  },
  'tours': <String, dynamic>{
    'home': <Map<String, dynamic>>[
      <String, dynamic>{'target': null, 'title': 'سلام! من لونام 💜', 'text': '{jan} خوش اومدی به نکسورا! بیا با هم یه دور بزنیم که همه‌جا رو بشناسی.'},
      <String, dynamic>{'target': 'area:top', 'title': 'بالای صفحه', 'text': 'این‌جا پروفایل و سطح و سکه‌هاته. با بازی و جایزه‌ی روزانه بیشترش کن ✨'},
      <String, dynamic>{'target': 'key:dock', 'title': 'نوار پایین', 'text': 'خانه، چت، روم‌ها، تورنمنت و بیشتر؛ همه از این‌جا.'},
    ],
    'rooms': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:top', 'title': 'روم‌ها', 'text': 'این‌جا با بقیه حرف می‌زنی و بعد با هم بازی می‌کنین 🎙️'},
    ],
    'games': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:center', 'title': 'بازی‌ها', 'text': 'یکی رو انتخاب کن؛ با ربات، با دوستات یا آنلاین 🎮'},
    ],
    'game_setup': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:top', 'title': 'آماده‌شدن', 'text': 'حالت بازی رو انتخاب کن، قوانین رو بخون و {jan} شروع کن!'},
    ],
    'tournaments': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:top', 'title': 'تورنمنت‌ها', 'text': 'جام‌ها این‌جان؛ ثبت‌نام کن و قبل از شروع چک‌این یادت نره ⏰'},
    ],
    'shop': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:top', 'title': 'فروشگاه', 'text': 'تم، قاب، مهره و کلی چیز قشنگ 🛍️ قیمت‌ها رو سرور چک می‌کنه.'},
    ],
    'social': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:top', 'title': 'چت', 'text': 'دوستات، پیام‌ها و روم‌های صوتی این‌جان 💬'},
    ],
    'chat': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:top', 'title': 'گپ‌ها', 'text': 'چت خصوصی، گروه و کانال؛ تماس صوتی و تصویری هم داری 📞'},
    ],
    'profile': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:top', 'title': 'پروفایل', 'text': 'آمار واقعی و دستاوردهات این‌جاست. من فقط تعریف می‌کنم، دروغ نمی‌گم 😌'},
    ],
    'settings': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:top', 'title': 'تنظیمات', 'text': 'صدا، لرزش، تم و این‌که کدوممون (من یا اوراکل) همراهت باشه 💜'},
    ],
    'oracle': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:bottom', 'title': 'گفتگو با لونا', 'text': '{jan} هرچی دلت خواست بپرس: قوانین، آمار، پیشنهاد بازی یا فقط یه گپ دوستانه.'},
    ],
    'admin': <Map<String, dynamic>>[
      <String, dynamic>{'target': 'area:top', 'title': 'پنل مدیریت', 'text': 'این‌جا مخصوص مدیرهاست؛ همه‌ی کارها ثبت می‌شن.'},
    ],
  },
  'jan_replies': <Map<String, dynamic>>[
    <String, dynamic>{'patterns': <String>['گل کوچیک', 'گلکوچیک', 'فوتبال انگشتی', 'gol kochik'], 'reply': '{jan} بریم گل‌کوچیک! من تیم تو رو تشویق می‌کنم ⚽'},
    <String, dynamic>{'patterns': <String>['بریم مسابقه', 'مسابقه بدیم', 'بریم بازی کنیم'], 'reply': '{jan} بزن بریم! 🎮'},
    <String, dynamic>{'patterns': <String>['نظرت چیه', 'نظرت چیست'], 'reply': 'نظر من؟ تو همیشه عالی‌ای! حالا دقیقاً درباره‌ی چی؟ 💜'},
    <String, dynamic>{'patterns': <String>['خسته ام', 'خستم', 'حوصلم سر رفته', 'حوصله ندارم'], 'reply': '{jan} بیا یه بازی کوچولو و آروم بزنیم، حالت بهتر می‌شه 🌸'},
    <String, dynamic>{'patterns': <String>['دوستت دارم', 'عاشقتم'], 'reply': 'منم دوستت دارم {jan}! 💜 حالا بریم یه برد بگیریم؟'},
    <String, dynamic>{'patterns': <String>['چیکار کنم', 'چی کار کنم', 'چکار کنم'], 'reply': 'جایزه‌ی روزانه‌تو بگیر، بعد یه بازی با ربات بزن ✨'},
  ],
  'wake_words': <String>['لونا', 'لونایی', 'لونا جان', 'luna', 'lona', 'loona', 'هی لونا'],
};
