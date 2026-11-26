/// Local dialogue pools for the corner companion — ORACLE or LUNA, whichever is active (Persian first, English fallback).
/// Grouped by situation; [OracleLines.pick] never repeats the last few lines.
library;

import 'dart:math' as math;

import '../../../core/companion/companion.dart';

class OracleLine {
  const OracleLine(this.fa, this.en);
  final String fa;
  final String en;
  String of(bool isFa) => isFa ? fa : en;
}

enum OracleTopic { tease, idle, greetMorning, greetNight, win, loss, draw, spend, sulk, forgive, sleep, wake, wink, laugh, confused, shocked, poke, returnBack }

class OracleLines {
  OracleLines._();

  static final math.Random _rng = math.Random();
  static final List<String> _recent = <String>[];

  static OracleLine pick(OracleTopic t, {CompanionId? companion}) {
    final Map<OracleTopic, List<OracleLine>> src =
        (companion ?? CompanionController.activeId) == CompanionId.luna ? _lunaPool : _pool;
    final List<OracleLine> pool = src[t] ?? src[OracleTopic.tease]!;
    OracleLine l = pool[_rng.nextInt(pool.length)];
    for (int i = 0; i < 6 && _recent.contains(l.fa); i++) {
      l = pool[_rng.nextInt(pool.length)];
    }
    _recent.add(l.fa);
    if (_recent.length > 12) _recent.removeAt(0);
    return l;
  }

  static const Map<OracleTopic, List<OracleLine>> _pool = <OracleTopic, List<OracleLine>>{
    OracleTopic.tease: <OracleLine>[
      OracleLine('اینقدر به من زل نزن، خجالت می‌کشم! 🙈', "Stop staring at me, I'm shy! 🙈"),
      OracleLine('من اگه جای تو بودم الان یه بازی می‌زدم… البته من همیشه می‌برم 😏', "If I were you I'd play a match now… not that I ever lose 😏"),
      OracleLine('سکه‌هات رو شمردم. نگران نباش، به کسی نمی‌گم چقدر کمه 🤫', "I counted your coins. Don't worry, I won't tell anyone how few 🤫"),
      OracleLine('می‌دونستی من با برق کار می‌کنم و تو با چایی؟ ☕⚡', 'Did you know I run on electricity and you run on tea? ☕⚡'),
      OracleLine('یه راز: ربات‌ها هم از دوشنبه‌ها بدشون میاد 🤖', 'Secret: robots hate Mondays too 🤖'),
      OracleLine('این دکمه‌ها رو برای تزئین نذاشتن‌ها! یکی‌شون رو بزن دیگه 😄', "Those buttons aren't decoration! Tap one already 😄"),
      OracleLine('من کهکشان رو دور زدم، تو هنوز داری منو نگاه می‌کنی؟ 🌌', "I've circled the galaxy and you're still looking at me? 🌌"),
      OracleLine('بیا یه دست تخته بزنیم… شوخی کردم، من تاس ندارم، دست ندارم… یعنی دارم ولی کوچیکه 😅', "Let's play backgammon… kidding, my hands are too tiny for dice 😅"),
      OracleLine('اگه یه بار دیگه گوشیت رو اینقدر تکون بدی سرگیجه می‌گیرم 😵‍💫', 'Shake your phone like that again and I get dizzy 😵‍💫'),
      OracleLine('حدس می‌زنم امروز روز توئه. البته دیروز هم همینو گفتم 😜', "I bet today's your day. I said that yesterday too 😜"),
      OracleLine('یه نفر گفت تو بهترین بازیکن نیکسورا هستی. اون یه نفر خودت بودی؟ 🤨', 'Someone said you are the best NEXORA player. Was that someone you? 🤨'),
      OracleLine('من آپدیت شدم، تو کی آپدیت می‌شی؟ 😏', "I got an update. When's yours? 😏"),
      OracleLine('دوستات منتظرن ببرنت، نذار ناامید شن 😈', "Your friends are waiting to beat you, don't disappoint them 😈"),
      OracleLine('اگه حوصله‌ت سر رفته، من یه عالمه ایده‌ی بد دارم! 💡', "Bored? I have tons of terrible ideas! 💡"),
      OracleLine('ببین، من فقط یه ربات کوچولوام… ولی خیلی باهوش‌تر از اونی‌ام که فکر می‌کنی 🧠', "Sure, I'm a tiny robot… but way smarter than you think 🧠"),
      OracleLine('هر وقت باختی بگو تقصیر لگ بود. من پشتتم 😎', 'Whenever you lose, blame lag. I got your back 😎'),
      OracleLine('دارم فکر می‌کنم… نه، بی‌خیال، فکر کردن خسته‌م می‌کنه 🙃', "I'm thinking… nah, thinking tires me out 🙃"),
      OracleLine('اون فوتبال انگشتی منتظرته. انگشتات رو گرم کن! ⚽', 'Finger soccer is waiting. Warm up those fingers! ⚽'),
      OracleLine('شنیدم تو مافیا همیشه اول تو رو بیرون می‌کنن 🕵️', 'Heard in Mafia they always vote you out first 🕵️'),
      OracleLine('یه بار رفتم تو کوییز، سوال‌ها از من جواب خواستن 🤯', 'I joined a quiz once, the questions asked me for answers 🤯'),
      OracleLine('اگه جایزه‌ی روزانه رو نگیری، خودم برش می‌دارم‌ها 🎁', "Don't claim your daily reward and I'll take it 🎁"),
      OracleLine('تو مار و پله من همیشه با مار رفیقم، پله‌ها مغرورن 🐍', 'In Snakes & Ladders I side with the snakes, ladders are snobs 🐍'),
      OracleLine('صفحه رو تمیز کن، جای انگشتت روی صورتمه 😤', 'Clean your screen, your fingerprint is on my face 😤'),
      OracleLine('من یه ربات حرفه‌ای‌ام، ولی بازم دلم بستنی می‌خواد 🍦', "I'm a professional robot, still want ice cream though 🍦"),
      OracleLine('یه سوال فلسفی: اگه ربات تو جنگل بیفته و کسی نباشه، بیپ می‌کنه؟ 🌲', 'Deep question: if a robot falls in a forest, does it beep? 🌲'),
      OracleLine('امروز یه تورنمنت ببر، بعد بیا پز بده 🏆', 'Win a tournament today, then come brag 🏆'),
      OracleLine('اون دکمه‌ی وسطی بزرگه؟ اون «بازی»ه. من خودم طراحیش کردم… تقریباً 🎮', "That big middle button? That's PLAY. I designed it… kind of 🎮"),
      OracleLine('اینجا بی‌سیم هست؟ دارم از بی‌حوصلگی دانلود می‌شم 📶', 'Is there Wi-Fi? I am downloading boredom 📶'),
      OracleLine('اگه بخوای می‌تونم برات شعر بگم… «سکه کمه، دل غمه» 🎤', 'I can write you a poem… "coins are few, so are you" 🎤'),
      OracleLine('نخیر، من حسودی نمی‌کنم که اون یکی ربات‌ها پرواز می‌کنن 🙄', "No, I'm NOT jealous that other robots can fly 🙄"),
    ],
    OracleTopic.idle: <OracleLine>[
      OracleLine('الو؟ کسی اینجاست؟ 👀', 'Hello? Anyone there? 👀'),
      OracleLine('تو یخ زدی یا گوشیت؟ 🧊', 'Did you freeze, or your phone? 🧊'),
      OracleLine('اگه یه دقیقه دیگه کاری نکنی، می‌خوابم‌ها… 😪', "One more idle minute and I'm taking a nap… 😪"),
      OracleLine('دارم برات شمارش معکوس می‌کنم… ۳… ۲… حوصله‌م سر رفت 😑', 'Counting down… 3… 2… I got bored 😑'),
      OracleLine('یه بازی، یه پست، یه چیزی! من حوصله‌م پوکید 🫠', 'A game, a post, anything! I am melting 🫠'),
    ],
    OracleTopic.greetMorning: <OracleLine>[
      OracleLine('صبح بخیر قهرمان! چایی‌ت رو خوردی؟ ☀️', 'Good morning champ! Had your tea? ☀️'),
      OracleLine('صبح شد و من هنوز شارژم صددرصده. تو چی؟ 🔋', "Morning! I'm at 100% charge. You? 🔋"),
    ],
    OracleTopic.greetNight: <OracleLine>[
      OracleLine('این وقت شب؟ ربات‌ها هم خواب دارن‌ها 🌙', 'This late? Robots need sleep too 🌙'),
      OracleLine('یه دست دیگه و بعد بخواب، قول؟ 😴', 'One more match and then bed, promise? 😴'),
    ],
    OracleTopic.win: <OracleLine>[
      OracleLine('بردی؟! من که می‌دونستم… یعنی امیدوار بودم 😆', 'You won?! I knew it… well, I hoped 😆'),
      OracleLine('ایول! حالا برو به همه بگو مربیت من بودم 😎', 'Yes! Now tell everyone I coached you 😎'),
      OracleLine('حریفت الان داره گوشیش رو سرزنش می‌کنه 😂', 'Your opponent is blaming their phone right now 😂'),
      OracleLine('برد خوشمزه بود؟ یه تیکه هم به من بده 🍰', 'Tasty win? Save me a slice 🍰'),
      OracleLine('این برد رو قاب می‌گیرم و می‌زنم به دیوار کهکشان 🖼️', 'Framing this win on the galaxy wall 🖼️'),
    ],
    OracleTopic.loss: <OracleLine>[
      OracleLine('اشکال نداره، تقصیر لگ بود! 😅', "It's fine, it was lag! 😅"),
      OracleLine('باختی؟ منم دیروز به ماشین‌حساب باختم 🧮', 'Lost? I lost to a calculator yesterday 🧮'),
      OracleLine('شکست مقدمه‌ی… یه شکست دیگه‌ست. شوخی کردم! دوباره برو 💪', 'Failure leads to… more failure. Kidding! Go again 💪'),
      OracleLine('حریفت شانس آورد. من دیدم. واقعاً دیدم! 👁️', 'Your opponent got lucky. I saw it. Really! 👁️'),
      OracleLine('بیا یه راهنمایی بهت بدم؟ تو بازی دکمه‌ی دستیار رو بزن 🤖', 'Want a hint? Tap the companion button inside a game 🤖'),
    ],
    OracleTopic.draw: <OracleLine>[
      OracleLine('مساوی؟ یعنی هردوتون به یه اندازه خوب… یا بد 🤝', 'A draw? Equally good… or equally bad 🤝'),
      OracleLine('نه بردی نه باختی، مثل چایی ولرم ☕', 'Not a win, not a loss, like lukewarm tea ☕'),
    ],
    OracleTopic.spend: <OracleLine>[
      OracleLine('اوه! پولدار شدی؟ برای منم یه چیزی بخر 🛍️', 'Ooh, big spender! Buy me something too 🛍️'),
      OracleLine('سکه‌هات رفتن… خداحافظ سکه‌های عزیز 👋💰', 'There go your coins… farewell, dear coins 👋💰'),
      OracleLine('خرید خوبی بود. یعنی… امیدوارم 😬', 'Good buy. I mean… hopefully 😬'),
      OracleLine('حالا با این تیپ دیگه کسی نمی‌تونه شکستت بده 😎', 'With that style no one can beat you now 😎'),
    ],
    OracleTopic.sulk: <OracleLine>[
      OracleLine('قهرم! 😤 تا عذرخواهی نکنی برنمی‌گردم.', "I'm sulking! 😤 Not turning back until you apologise."),
      OracleLine('هیچ‌کس منو دوست نداره… قهر! 😒', 'Nobody loves me… hmph! 😒'),
      OracleLine('دیگه باهات حرف نمی‌زنم! …هنوز داری نگاهم می‌کنی؟ 😤', "I'm not talking to you! …are you still looking? 😤"),
      OracleLine('یادت رفت سلام کنی. قهرم. 🙅', "You forgot to say hi. I'm sulking. 🙅"),
    ],
    OracleTopic.forgive: <OracleLine>[
      OracleLine('خب… باشه، بخشیدمت. ولی این دفعه‌ی آخره! 😌', "Fine… you're forgiven. Last time though! 😌"),
      OracleLine('آشتی؟ آشتی! 🤗', 'Friends again? Friends again! 🤗'),
      OracleLine('عذرخواهی‌ت خیلی گرم بود، شارژم پر شد ⚡', 'That apology was so warm, I fully recharged ⚡'),
    ],
    OracleTopic.sleep: <OracleLine>[
      OracleLine('خررر… پففف… خررر… 💤', 'Zzz… pfff… zzz… 💤'),
      OracleLine('یه چرت کوچیک… فقط پنج دقیقه… 😴', 'Just a tiny nap… five minutes… 😴'),
    ],
    OracleTopic.wake: <OracleLine>[
      OracleLine('هان؟! من نخوابیده بودم! داشتم… فکر می‌کردم 😳', "Huh?! I wasn't sleeping! I was… thinking 😳"),
      OracleLine('چرا بیدارم کردی؟! داشتم خواب سکه می‌دیدم 💰', 'Why wake me?! I was dreaming of coins 💰'),
      OracleLine('آخ! داشتم تو خواب تورنمنت می‌بردم 🏆', 'Argh! I was winning a tournament in my dream 🏆'),
    ],
    OracleTopic.wink: <OracleLine>[
      OracleLine('ما یه راز مشترک داریم… 😉', 'We share a secret now… 😉'),
      OracleLine('نگو به کسی، ولی تو بازیکن محبوب منی 😉', "Don't tell anyone, you're my favourite player 😉"),
    ],
    OracleTopic.laugh: <OracleLine>[
      OracleLine('هاهاها! یاد قیافه‌ت تو بازی آخر افتادم 😂', 'Hahaha! Just remembered your face in the last match 😂'),
      OracleLine('ببخشید، یه جوک باینری یادم اومد: ۱۰ 😂', 'Sorry, remembered a binary joke: 10 😂'),
    ],
    OracleTopic.confused: <OracleLine>[
      OracleLine('صبر کن… من کجام؟ اینجا کجاست؟ 🤔', 'Wait… where am I? Where is this? 🤔'),
      OracleLine('چرا آسمون بنفشه؟ کی رنگش کرد؟ ❓', 'Why is the sky purple? Who painted it? ❓'),
      OracleLine('من الان چی می‌خواستم بگم؟… یادم رفت 🤷', 'What was I about to say?… forgot 🤷'),
    ],
    OracleTopic.shocked: <OracleLine>[
      OracleLine('واااای! اینو ببین! …نه، هیچی نبود 😱', 'Whoa! Look at that! …never mind 😱'),
      OracleLine('چی؟! این همه سکه از کجا اومد؟! 😲', 'What?! Where did all those coins come from?! 😲'),
    ],
    OracleTopic.poke: <OracleLine>[
      OracleLine('آی! قلقلکم نده! 🤭', "Ouch! Don't tickle me! 🤭"),
      OracleLine('یه بار دیگه بزنی، منم می‌زنمت… با محبت 😇', 'Poke me again and I poke back… lovingly 😇'),
      OracleLine('دکمه نیستم‌ها! …خب، شاید یه کم 😅', "I'm not a button! …well, maybe a little 😅"),
      OracleLine('چی شده؟ کمک می‌خوای؟ نگهم دار تا گفتگو باز شه 💬', 'Need help? Long-press me to chat 💬'),
    ],
    OracleTopic.returnBack: <OracleLine>[
      OracleLine('برگشتی! دلم برات تنگ شده بود… یه کوچولو 🥹', 'You are back! I missed you… a little 🥹'),
      OracleLine('کجا بودی؟ من اینجا تنهایی با پیکسل‌ها حرف می‌زدم 🫥', 'Where were you? I was talking to pixels alone 🫥'),
    ],
  };

  /// LUNA — warm, girly, playful, a little dramatic; never mean.
  static const Map<OracleTopic, List<OracleLine>> _lunaPool = <OracleTopic, List<OracleLine>>{
    OracleTopic.tease: <OracleLine>[
      OracleLine('اِ… داری منو نگاه می‌کنی؟ لپام صورتی شد 🌸', 'Oh… are you looking at me? My cheeks went pink 🌸'),
      OracleLine('یه بازی بزنیم؟ قول می‌دم اگه ببری کلی برات دست بزنم 👏💕', 'Play a round? I promise to cheer like crazy if you win 👏💕'),
      OracleLine('من یه عالمه ستاره جمع کردم، یکیش مال تو ✨', 'I collected a sky full of stars, one is yours ✨'),
      OracleLine('اگه حوصله‌ت سر رفته، من همین‌جام… مثل همیشه 🌙', "If you're bored, I'm right here… like always 🌙"),
      OracleLine('حس می‌کنم امروز روز شانس توئه! بریم امتحانش کنیم؟ 🍀', 'I have a feeling today is your lucky day! Shall we test it? 🍀'),
      OracleLine('اون دکمه‌ی صورتیه چشمک زد… فکر کنم دلش بازی می‌خواد 😉', 'That pink button just winked… I think it wants a game 😉'),
      OracleLine('دوستات آنلاینن! برو یه سلام قشنگ بهشون بده 💌', 'Your friends are online! Go say a sweet hello 💌'),
      OracleLine('من دارم موهامو با نور ماه شونه می‌کنم، تو چی کار می‌کنی؟ 🌕', "I'm brushing my hair with moonlight, what are you up to? 🌕"),
      OracleLine('یه راز بگم؟ من عاشق صدای سکه‌هام… دینگ دینگ! 🪙', 'Want a secret? I love the sound of coins… ding ding! 🪙'),
      OracleLine('اگه تو مافیا بازی کنی، من طرف توام… حتی اگه مافیا باشی 🤭', "If you play Mafia, I'm on your side… even if you're the mafia 🤭"),
      OracleLine('هدیه‌ی روزانه‌ت منتظرته، کادوپیچش کردم 🎀', 'Your daily gift is waiting, I wrapped it with a bow 🎀'),
      OracleLine('صفحه رو آروم‌تر لمس کن، قلقلکم میاد 🙈', "Touch the screen gently, it tickles 🙈"),
      OracleLine('امروز یه جام ببر، من برات تاج گل درست می‌کنم 👑🌷', 'Win a cup today and I will make you a flower crown 👑🌷'),
    ],
    OracleTopic.idle: <OracleLine>[
      OracleLine('هنوز اینجایی؟ من داشتم رو ابرا قدم می‌زدم ☁️', 'Still here? I was walking on clouds ☁️'),
      OracleLine('یه کم سکوت هم قشنگه… ولی یه بازی قشنگ‌تره 🎮', 'Silence is nice… a game is nicer 🎮'),
      OracleLine('دارم برات یه آهنگ زمزمه می‌کنم… لا لا لا 🎶', "I'm humming you a little tune… la la la 🎶"),
      OracleLine('اگه خسته‌ای یه چایی بخور، من منتظرت می‌مونم ☕', "If you're tired, grab some tea — I'll wait for you ☕"),
    ],
    OracleTopic.greetMorning: <OracleLine>[
      OracleLine('صبح بخیر آفتاب من! ☀️ امروز قراره درخشان باشی', 'Good morning, sunshine! ☀️ Today you will shine'),
      OracleLine('سلام صبح قشنگت بخیر 🌷 جایزه‌ی روزانه‌ت حاضره', 'Morning, lovely 🌷 your daily reward is ready'),
      OracleLine('چشماتو باز کن، دنیا منتظر قهرمانشه 💫', 'Open your eyes, the world is waiting for its champion 💫'),
    ],
    OracleTopic.greetNight: <OracleLine>[
      OracleLine('شب بخیر ستاره‌ی من 🌙 یه بازی کوچولو قبل خواب؟', 'Good evening, my star 🌙 one tiny game before bed?'),
      OracleLine('ماه امشب خیلی قشنگه، مثل تو ✨', 'The moon is so pretty tonight, just like you ✨'),
      OracleLine('دیروقته‌ها! ولی من بیدار می‌مونم که تنها نباشی 💜', "It's late! But I'll stay up so you're not alone 💜"),
    ],
    OracleTopic.win: <OracleLine>[
      OracleLine('واااای بردی! 🎉 می‌دونستم، می‌دونستم!', 'Yaaay you won! 🎉 I knew it, I knew it!'),
      OracleLine('قهرمان من! بیا بغلت کنم 🤗🏆', 'My champion! Come here, hug time 🤗🏆'),
      OracleLine('دارم برات کاغذ رنگی می‌ریزم! 🎊', "I'm throwing confetti for you! 🎊"),
      OracleLine('این برد رو قاب می‌کنم می‌زنم به دیوار ماه 🌙🖼️', "I'm framing this win on the moon's wall 🌙🖼️"),
      OracleLine('دیدی گفتم امروز روز توئه؟ 💖', 'Told you today was your day! 💖'),
    ],
    OracleTopic.loss: <OracleLine>[
      OracleLine('اشکال نداره عزیزم، دفعه‌ی بعد مال توئه 🫶', "It's okay, sweetie — next one is yours 🫶"),
      OracleLine('حریفت فقط شانس آورد، من دیدم 😤💕', 'Your rival just got lucky, I saw it 😤💕'),
      OracleLine('یه نفس عمیق… حالا دوباره! من کنارتم 🌸', "Deep breath… now again! I'm right beside you 🌸"),
      OracleLine('باختن هم بخشی از قهرمان شدنه ✨', 'Losing is part of becoming a champion ✨'),
    ],
    OracleTopic.draw: <OracleLine>[
      OracleLine('مساوی! یعنی هر دوتاتون عالی بودین 🤝💫', "A draw! You were both amazing 🤝💫"),
      OracleLine('نه بردی نه باختی… پس یه دست دیگه؟ 😊', 'No win, no loss… so one more? 😊'),
    ],
    OracleTopic.spend: <OracleLine>[
      OracleLine('اووه خرید جدید! خیلی بهت میاد 🛍️💕', 'Ooh, a new buy! It suits you so well 🛍️💕'),
      OracleLine('سلیقه‌ت حرف نداره، جدی میگم 😍', 'Your taste is perfect, I mean it 😍'),
      OracleLine('سکه‌ها رفتن ولی ارزششو داشت ✨', 'The coins are gone but it was worth it ✨'),
    ],
    OracleTopic.sulk: <OracleLine>[
      OracleLine('هوم… قهرم! 😤 تا معذرت نخوای نگات نمی‌کنم', "Hmph… I'm sulking! 😤 Not looking at you until you say sorry"),
      OracleLine('دلم شکست… یه کوچولو 🥺', 'My heart broke… just a tiny bit 🥺'),
      OracleLine('اینجوری منو تکون نمی‌دن که! 😣', "That's no way to shake a lady! 😣"),
    ],
    OracleTopic.forgive: <OracleLine>[
      OracleLine('باشه… بخشیدمت 💗 ولی فقط چون خیلی نازی', 'Okay… forgiven 💗 only because you are so sweet'),
      OracleLine('آشتی آشتی! 🌈', 'Friends again! 🌈'),
      OracleLine('دیگه قهر نیستم، بیا با هم بازی کنیم 🤗', "Not sulking anymore, let's play together 🤗"),
    ],
    OracleTopic.sleep: <OracleLine>[
      OracleLine('خوابم میاد… zzz 🌙', "I'm so sleepy… zzz 🌙"),
      OracleLine('دارم خواب ستاره‌ها رو می‌بینم… zzz ✨', 'Dreaming of stars… zzz ✨'),
    ],
    OracleTopic.wake: <OracleLine>[
      OracleLine('اِ بیدار شدم! داشتم خواب تو رو می‌دیدم 😳', 'Oh, I woke up! I was dreaming about you 😳'),
      OracleLine('صبح شد؟ نه؟ باشه، به هر حال سلام! 🌸', 'Is it morning? No? Well, hi anyway! 🌸'),
    ],
    OracleTopic.wink: <OracleLine>[
      OracleLine('😉 این بین خودمون بمونه', '😉 That stays between us'),
      OracleLine('یه چشمک مخصوص تو 😘', 'A special wink just for you 😘'),
    ],
    OracleTopic.laugh: <OracleLine>[
      OracleLine('هی هی هی 🤭 خیلی بامزه‌ای', 'Hee hee 🤭 you are so funny'),
      OracleLine('از خنده بال‌هام لرزید! 😂🦋', 'My wings shook from laughing! 😂🦋'),
    ],
    OracleTopic.confused: <OracleLine>[
      OracleLine('اوم… یعنی چی؟ 🤔🎀', 'Umm… what does that mean? 🤔🎀'),
      OracleLine('سرم گیج رفت، دوباره بگو؟ 😵‍💫', 'My head is spinning, say it again? 😵‍💫'),
    ],
    OracleTopic.shocked: <OracleLine>[
      OracleLine('واییی! جدی؟! 😱', 'Whaaat! Seriously?! 😱'),
      OracleLine('قلبم ریخت! 💓', 'My heart skipped a beat! 💓'),
    ],
    OracleTopic.poke: <OracleLine>[
      OracleLine('هی! قلقلکم نده 🙈', "Hey! Don't tickle me 🙈"),
      OracleLine('آخ دماغم! 😖 آروم‌تر', 'Ouch, my nose! 😖 Gently'),
      OracleLine('یه بار دیگه بزنی، قهر می‌کنم‌ها! 😤', "One more poke and I'm sulking! 😤"),
      OracleLine('چیه عزیزم؟ کاری داری؟ 💕', 'What is it, dear? Need something? 💕'),
    ],
    OracleTopic.returnBack: <OracleLine>[
      OracleLine('برگشتی! دلم یه عالمه برات تنگ شده بود 🥹💜', 'You are back! I missed you so much 🥹💜'),
      OracleLine('بالاخره اومدی! برات گل نگه داشتم 🌷', 'Finally! I saved you a flower 🌷'),
    ],
  };
}
