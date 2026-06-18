#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "marketing" / "raw"
OUT = ROOT / "marketing" / "app-store"
ICON = ROOT / "iTunesArtwork@2x.png"
_MOCKUP_LOCAL = ROOT / "marketing" / "assets" / "mockup.png"
_MOCKUP_AGENTS = Path("/Users/jamespikover/.agents/skills/app-store-screenshots/mockup.png")
MOCKUP = _MOCKUP_LOCAL if _MOCKUP_LOCAL.exists() else _MOCKUP_AGENTS

CANVAS_W = 1320
CANVAS_H = 2868

SIZES = {
    "iphone-6.9": (1320, 2868),
    "iphone-6.5": (1284, 2778),
    "iphone-6.3": (1206, 2622),
    "iphone-6.1": (1125, 2436),
}

IPAD_SIZES = {
    "ipad-13": (2064, 2752),
    "ipad-12.9": (2048, 2732),
}

IPAD_CANVAS_W = 2064
IPAD_CANVAS_H = 2752


@dataclass(frozen=True)
class Slide:
    slug: str
    source: str
    headline: str
    subline: str
    top: tuple[int, int, int]
    bottom: tuple[int, int, int]
    accent: tuple[int, int, int]
    phone_width: int = 780
    phone_y: int = 900
    phone_x: int = 270
    scrub_y: int | None = None
    dark_text: bool = False


# ── Localized text overrides ──────────────────────────────────────────
# Keys: (slide_index, field) where field is "headline", "subline", "footer_left", "footer_right", or "app_subtitle"
# The footer_left / footer_right / app_subtitle are shared across all slides for a locale.
# Slide-specific keys use 0-based index matching SLIDES order.

LOCALE_TEXT: dict[str, dict] = {
    "en": {},  # default — uses values from Slide dataclass
    "de-DE": {
        "app_subtitle": "Ziffernblock-Tastatur",
        "footer_left": "Kein Abo erforderlich für Pro.",
        "footer_right": "Funktioniert in jeder App",
        (0, "headline"): "Zahlen\nohne\nVerzögerung",
        (0, "subline"): "Ein echtes Nummernpad in jeder App.",
        (1, "headline"): "Schnellere\nFormulare",
        (1, "subline"): "Kartennummern, Codes, Summen.",
        (2, "headline"): "Steuer und\nTrinkgeld",
        (2, "subline"): "Lang drücken auf % für Summen.",
        (3, "headline"): "Zuletzt\nkopierte\nZahlen",
        (3, "subline"): "Zwischenablage bleibt auf dem Gerät.",
        (4, "headline"): "Pro-Pakete\nfür die Arbeit",
        (4, "subline"): "Finanzen, Symbole, Mathe, Code.",
        (5, "headline"): "Dein Numpad\ndein Stil",
        (5, "subline"): "Themen für jeden Moment.",
    },
    "fr-FR": {
        "app_subtitle": "Clavier Numérique",
        "footer_left": "Pas d'abonnement pour Pro.",
        "footer_right": "Fonctionne partout",
        (0, "headline"): "Des chiffres\nsans\nralentir",
        (0, "subline"): "Un vrai pavé numérique partout.",
        (1, "headline"): "Formulaires\nplus rapides",
        (1, "subline"): "Numéros de carte, codes, totaux.",
        (2, "headline"): "Taxes et\npourboire",
        (2, "subline"): "Appui long sur % pour les totaux.",
        (3, "headline"): "Collez vos\nnombres\nrécents",
        (3, "subline"): "Historique du presse-papiers local.",
        (4, "headline"): "Packs Pro\npour le travail",
        (4, "subline"): "Finance, symboles, maths, code.",
        (5, "headline"): "Votre pavé\nvotre style",
        (5, "subline"): "Des thèmes pour chaque moment.",
    },
    "ja": {
        "app_subtitle": "テンキーボード",
        "footer_left": "サブスク不要でPro。",
        "footer_right": "どのアプリでも使える",
        (0, "headline"): "もたつかない\n数字入力",
        (0, "subline"): "どのアプリでも使えるテンキー。",
        (1, "headline"): "フォーム入力\nを高速化",
        (1, "subline"): "カード番号、コード、合計。",
        (2, "headline"): "税金と\nチップ",
        (2, "subline"): "%キーを長押しで計算。",
        (3, "headline"): "最近の\n数字を\nペースト",
        (3, "subline"): "クリップボード履歴は端末内。",
        (4, "headline"): "仕事用\nProパック",
        (4, "subline"): "金融、記号、数学、コード。",
        (5, "headline"): "あなたの\nテンキー\nあなたのスタイル",
        (5, "subline"): "場面に合うテーマ。",
    },
    "es-MX": {
        "app_subtitle": "Teclado Numérico",
        "footer_left": "Sin suscripción para Pro.",
        "footer_right": "Funciona en toda app",
        (0, "headline"): "Números\nsin\nretrasos",
        (0, "subline"): "Un teclado numérico real en toda app.",
        (1, "headline"): "Formularios\nmás rápidos",
        (1, "subline"): "Números de tarjeta, códigos, totales.",
        (2, "headline"): "Impuesto y\npropina",
        (2, "subline"): "Mantén pulsado % para totales.",
        (3, "headline"): "Pega números\nrecientes",
        (3, "subline"): "Historial del portapapeles local.",
        (4, "headline"): "Paquetes Pro\npara el trabajo",
        (4, "subline"): "Finanzas, símbolos, mates, código.",
        (5, "headline"): "Tu numpad\ntu estilo",
        (5, "subline"): "Temas para cada momento.",
    },
    "pt-BR": {
        "app_subtitle": "Teclado Numérico",
        "footer_left": "Sem assinatura para Pro.",
        "footer_right": "Funciona em qualquer app",
        (0, "headline"): "Números\nsem\natrasos",
        (0, "subline"): "Um teclado numérico real em todo app.",
        (1, "headline"): "Formulários\nmais rápidos",
        (1, "subline"): "Números de cartão, códigos, totais.",
        (2, "headline"): "Imposto e\ngorjeta",
        (2, "subline"): "Pressione longo no % para totais.",
        (3, "headline"): "Cole números\nrecentes",
        (3, "subline"): "Histórico na área de transferência.",
        (4, "headline"): "Pacotes Pro\npara o trabalho",
        (4, "subline"): "Finanças, símbolos, matemática, código.",
        (5, "headline"): "Seu numpad\nseu estilo",
        (5, "subline"): "Temas que combinam com o momento.",
    },
    "zh-Hans": {
        "app_subtitle": "数字键盘",
        "footer_left": "Pro无需订阅。",
        "footer_right": "适用于所有应用",
        (0, "headline"): "快速输入\n数字",
        (0, "subline"): "每个应用中的真正数字键盘。",
        (1, "headline"): "更快填写\n表单",
        (1, "subline"): "卡号、验证码、合计。",
        (2, "headline"): "税费和\n小费",
        (2, "subline"): "长按%键即可计算。",
        (3, "headline"): "粘贴最近\n的数字",
        (3, "subline"): "剪贴板历史仅存于设备。",
        (4, "headline"): "Pro工作\n套件",
        (4, "subline"): "金融、符号、数学、代码。",
        (5, "headline"): "你的键盘\n你的风格",
        (5, "subline"): "适合每个场景的主题。",
    },
    "zh-Hant": {
        "app_subtitle": "數字鍵盤",
        "footer_left": "Pro無需訂閱。",
        "footer_right": "適用於所有應用",
        (0, "headline"): "快速輸入\n數字",
        (0, "subline"): "每個應用程式中的真正數字鍵盤。",
        (1, "headline"): "更快填寫\n表單",
        (1, "subline"): "卡號、驗證碼、合計。",
        (2, "headline"): "稅費和\n小費",
        (2, "subline"): "長按%鍵即可計算。",
        (3, "headline"): "貼上最近\n的數字",
        (3, "subline"): "剪貼簿歷史僅存於裝置。",
        (4, "headline"): "Pro工作\n套件",
        (4, "subline"): "金融、符號、數學、程式碼。",
        (5, "headline"): "你的鍵盤\n你的風格",
        (5, "subline"): "適合每個場景的主題。",
    },
    "ko": {
        "app_subtitle": "숫자 키보드",
        "footer_left": "Pro 구독 필요 없음.",
        "footer_right": "모든 앱에서 사용 가능",
        (0, "headline"): "빠른\n숫자 입력",
        (0, "subline"): "모든 앱에서 쓰는 진짜 넘버패드.",
        (1, "headline"): "빠른\n양식 작성",
        (1, "subline"): "카드 번호, 코드, 합계.",
        (2, "headline"): "세금과\n팁",
        (2, "subline"): "합계가 중요할 때 %를 길게 누르세요.",
        (3, "headline"): "최근 숫자\n붙여넣기",
        (3, "subline"): "클립보드 기록은 기기에만 저장.",
        (4, "headline"): "업무용\nPro 팩",
        (4, "subline"): "금융, 기호, 수학, 코드.",
        (5, "headline"): "나만의\n넘버패드\n나만의 스타일",
        (5, "subline"): "순간에 맞는 테마.",
    },
    "th": {
        "app_subtitle": "คีย์บอร์ดตัวเลข",
        "footer_left": "Pro ไม่ต้องสมัครสมาชิก",
        "footer_right": "ใช้ได้ทุกแอป",
        (0, "headline"): "ใส่ตัวเลข\nไม่ต้อง\nรอช้า",
        (0, "subline"): "แป้นตัวเลขจริงในทุกแอป",
        (1, "headline"): "กรอกฟอร์ม\nเร็วขึ้น",
        (1, "subline"): "เลขบัตร โค้ด ยอดรวม",
        (2, "headline"): "ภาษีและ\nทิป",
        (2, "subline"): "กดค้าง % เมื่อต้องคำนวณ",
        (3, "headline"): "วางตัวเลข\nล่าสุด",
        (3, "subline"): "ประวัติคลิปบอร์ดอยู่ในเครื่อง",
        (4, "headline"): "แพ็ก Pro\nสำหรับงาน",
        (4, "subline"): "การเงิน สัญลักษณ์ คณิต โค้ด",
        (5, "headline"): "แป้นของคุณ\nสไตล์ของคุณ",
        (5, "subline"): "ธีมที่เข้ากับทุกช่วงเวลา",
    },
    "hi": {
        "app_subtitle": "अंक कीबोर्ड",
        "footer_left": "Pro के लिए सदस्यता नहीं।",
        "footer_right": "हर ऐप में काम करे",
        (0, "headline"): "बिना रुकावट\nअंक दर्ज\nकरें",
        (0, "subline"): "हर ऐप में असली नंबर पैड।",
        (1, "headline"): "तेज़\nफॉर्म भरें",
        (1, "subline"): "कार्ड नंबर, कोड, कुल।",
        (2, "headline"): "कर और\nटिप",
        (2, "subline"): "कुल के लिए % देर तक दबाएँ।",
        (3, "headline"): "हाल के\nअंक\nचिपकाएँ",
        (3, "subline"): "क्लिपबोर्ड इतिहास डिवाइस पर रहता है।",
        (4, "headline"): "कार्य के लिए\nPro पैक",
        (4, "subline"): "वित्त, प्रतीक, गणित, कोड।",
        (5, "headline"): "आपका नंबरपैड\nआपकी शैली",
        (5, "subline"): "हर पल के लिए थीम।",
    },
"ar-SA": {
        "app_subtitle": "لوحة أرقام",
        "footer_left": "بدون اشتراك للنسخة الاحترافية.",
        "footer_right": "يعمل في أي تطبيق",
        (0, "headline"): "أرقام\nبدون\nتأخير",
        (0, "subline"): "لوحة أرقام حقيقية في كل تطبيق.",
        (1, "headline"): "نماذج\nأسرع",
        (1, "subline"): "أرقام البطاقات، الرموز، المجاميع.",
        (2, "headline"): "ضريبة وبقشيش\nبنقرة واحدة",
        (2, "subline"): "اضغط مطوّلاً على % لحساب المجاميع.",
        (3, "headline"): "الصق أرقاماً\nحديثة",
        (3, "subline"): "سجل الحافظة يبقى على جهازك.",
        (4, "headline"): "حزم Pro\nللعمل",
        (4, "subline"): "مالية، رموز، رياضيات، أكواد.",
        (5, "headline"): "لوحتك\nأسلوبك",
        (5, "subline"): "سمات تناسب كل لحظة.",
    },
    "bn-BD": {
        "app_subtitle": "নম্বর প্যাড কীবোর্ড",
        "footer_left": "Pro-এর জন্য সাবস্ক্রিপশন নেই।",
        "footer_right": "যেকোনো অ্যাপে কাজ করে",
        (0, "headline"): "দ্রুত\nসংখ্যা\nইনপুট",
        (0, "subline"): "প্রতিটি অ্যাপে আসল নম্বর প্যাড।",
        (1, "headline"): "দ্রুত\nফর্ম পূরণ",
        (1, "subline"): "কার্ড নম্বর, কোড, মোট।",
        (2, "headline"): "ট্যাক্স ও টিপ\nএক ট্যাপে",
        (2, "subline"): "মোট হিসাবে % দীর্ঘ চাপুন।",
        (3, "headline"): "সাম্প্রতিক\nসংখ্যা\nপেস্ট করুন",
        (3, "subline"): "ক্লিপবোর্ড ইতিহাস ডিভাইসে থাকে।",
        (4, "headline"): "কাজের জন্য\nPro প্যাক",
        (4, "subline"): "ফাইন্যান্স, সিম্বল, গণিত, কোড।",
        (5, "headline"): "আপনার প্যাড\nআপনার স্টাইল",
        (5, "subline"): "প্রতিটি মুহূর্তের জন্য থিম।",
    },
    "ca": {
        "app_subtitle": "Teclat Numèric",
        "footer_left": "Sense subscripció per a Pro.",
        "footer_right": "Funciona a qualsevol app",
        (0, "headline"): "Números\nsense\nretards",
        (0, "subline"): "Un teclat numèric real a cada app.",
        (1, "headline"): "Formularis\nmés ràpids",
        (1, "subline"): "Números de targeta, codis, totals.",
        (2, "headline"): "Impost i\npropina",
        (2, "subline"): "Manteniu % premut per als totals.",
        (3, "headline"): "Enganxeu\nnúmeros\nrecents",
        (3, "subline"): "L'historial del porta-retalls és local.",
        (4, "headline"): "Paquets Pro\nper treballar",
        (4, "subline"): "Finances, símbols, mates, codi.",
        (5, "headline"): "El teu teclat\nel teu estil",
        (5, "subline"): "Temes per a cada moment.",
    },
    "cs": {
        "app_subtitle": "Numerická klávesnice",
        "footer_left": "Pro bez předplatného.",
        "footer_right": "Funguje v každé aplikaci",
        (0, "headline"): "Čísla\nbez\nzdržení",
        (0, "subline"): "Skutečný numpad v každé aplikaci.",
        (1, "headline"): "Rychlejší\nformuláře",
        (1, "subline"): "Čísla karet, kódy, součty.",
        (2, "headline"): "Daň a\nspropitné",
        (2, "subline"): "Podržte % pro výpočet součtů.",
        (3, "headline"): "Vložte\nnedávná\nčísla",
        (3, "subline"): "Historie schránky zůstává v zařízení.",
        (4, "headline"): "Pro balíčky\npro práci",
        (4, "subline"): "Finance, symboly, matematika, kód.",
        (5, "headline"): "Váš numpad\nváš styl",
        (5, "subline"): "Motivy pro každý okamžik.",
    },
    "da": {
        "app_subtitle": "Numerisk tastatur",
        "footer_left": "Intet abonnement for Pro.",
        "footer_right": "Virker i alle apps",
        (0, "headline"): "Tal uden\nforsinkelser",
        (0, "subline"): "Et ægte numerisk tastatur i hver app.",
        (1, "headline"): "Hurtigere\nformularer",
        (1, "subline"): "Kortnumre, koder, totaler.",
        (2, "headline"): "Skat og\ndrikkepenge",
        (2, "subline"): "Hold % nede for at beregne.",
        (3, "headline"): "Indsæt\nseneste\ntal",
        (3, "subline"): "Udklipsholderhistorik forbliver lokal.",
        (4, "headline"): "Pro-pakker\ntil arbejde",
        (4, "subline"): "Finans, symboler, matematik, kode.",
        (5, "headline"): "Dit tastatur\ndin stil",
        (5, "subline"): "Temaer der passer til øjeblikket.",
    },
    "el": {
        "app_subtitle": "Αριθμητικό Πληκτρολόγιο",
        "footer_left": "Χωρίς συνδρομή για Pro.",
        "footer_right": "Λειτουργεί παντού",
        (0, "headline"): "Αριθμοί\nχωρίς\nκαθυστέρηση",
        (0, "subline"): "Πραγματικό numpad σε κάθε εφαρμογή.",
        (1, "headline"): "Πιο γρήγορες\nφόρμες",
        (1, "subline"): "Αριθμοί καρτών, κωδικοί, σύνολα.",
        (2, "headline"): "Φόρος και\nφιλοδώρημα",
        (2, "subline"): "Κρατήστε το % για υπολογισμό.",
        (3, "headline"): "Επικόλληση\nπρόσφατων\nαριθμών",
        (3, "subline"): "Ιστορικό πρόχειρου στη συσκευή σας.",
        (4, "headline"): "Πακέτα Pro\nγια δουλειά",
        (4, "subline"): "Χρηματοοικονομικά, σύμβολα, μαθ, κώδικας.",
        (5, "headline"): "Το numpad\nσου, το στιλ\nσου",
        (5, "subline"): "Θέματα που ταιριάζουν στη στιγμή.",
    },
    "en-AU": {},
    "en-CA": {},
    "en-GB": {},
    "es-ES": {
        "app_subtitle": "Teclado Numérico",
        "footer_left": "Sin suscripción para Pro.",
        "footer_right": "Funciona en cualquier app",
        (0, "headline"): "Números\nsin\nretrasos",
        (0, "subline"): "Un teclado numérico real en cada app.",
        (1, "headline"): "Formularios\nmás rápidos",
        (1, "subline"): "Números de tarjeta, códigos, totales.",
        (2, "headline"): "Impuesto y\npropina",
        (2, "subline"): "Mantén pulsado % para totales.",
        (3, "headline"): "Pega números\nrecientes",
        (3, "subline"): "Historial del portapapeles local.",
        (4, "headline"): "Paquetes Pro\npara el trabajo",
        (4, "subline"): "Finanzas, símbolos, mates, código.",
        (5, "headline"): "Tu numpad\ntu estilo",
        (5, "subline"): "Temas para cada momento.",
    },
    "fi": {
        "app_subtitle": "Numeronäppäimistö",
        "footer_left": "Ei tilausta Pro:lle.",
        "footer_right": "Toimii kaikissa sovelluksissa",
        (0, "headline"): "Numerot\nilman\nviivettä",
        (0, "subline"): "Aito numeronäppäimistö joka sovelluksessa.",
        (1, "headline"): "Nopeammat\nlomakkeet",
        (1, "subline"): "Korttinumerot, koodit, summat.",
        (2, "headline"): "Vero ja\ntippi",
        (2, "subline"): "Paina pitkään % summien laskemiseksi.",
        (3, "headline"): "Liitä\nviimeisimmät\nnumerot",
        (3, "subline"): "Leikepöytähistoria pysyy laitteessa.",
        (4, "headline"): "Pro-paketit\ntyöhön",
        (4, "subline"): "Rahoitus, symbolit, matematiikka, koodi.",
        (5, "headline"): "Sinun\nnäppäimistösi\nsinun tyylisi",
        (5, "subline"): "Teemoja jokaiseen hetkeen.",
    },
    "fr-CA": {
        "app_subtitle": "Clavier Numérique",
        "footer_left": "Pas d'abonnement pour Pro.",
        "footer_right": "Fonctionne partout",
        (0, "headline"): "Des chiffres\nsans\nralentir",
        (0, "subline"): "Un vrai pavé numérique partout.",
        (1, "headline"): "Formulaires\nplus rapides",
        (1, "subline"): "Numéros de carte, codes, totaux.",
        (2, "headline"): "Taxes et\npourboire",
        (2, "subline"): "Appui long sur % pour les totaux.",
        (3, "headline"): "Collez vos\nnombres\nrécents",
        (3, "subline"): "Historique du presse-papiers local.",
        (4, "headline"): "Packs Pro\npour le travail",
        (4, "subline"): "Finance, symboles, maths, code.",
        (5, "headline"): "Votre pavé\nvotre style",
        (5, "subline"): "Des thèmes pour chaque moment.",
    },
    "gu-IN": {
        "app_subtitle": "નંબર પેડ કીબોર્ડ",
        "footer_left": "Pro માટે સબસ્ક્રિપ્શન નહીં.",
        "footer_right": "કોઈપણ એપમાં કામ કરે",
        (0, "headline"): "વિલંબ વિના\nનંબર\nદાખલ કરો",
        (0, "subline"): "દરેક એપમાં ખરું નંબર પેડ.",
        (1, "headline"): "ઝડપી\nફોર્મ ભરો",
        (1, "subline"): "કાર્ડ નંબર, કોડ, કુલ.",
        (2, "headline"): "ટેક્સ અને\nટિપ",
        (2, "subline"): "કુલ માટે % લાંબું દબાવો.",
        (3, "headline"): "તાજેતરના\nનંબર\nપેસ્ટ કરો",
        (3, "subline"): "ક્લિપબોર્ડ ઇતિહાસ ડિવાઇસ પર રહે છે.",
        (4, "headline"): "કામ માટે\nPro પેક",
        (4, "subline"): "ફાઇનાન્સ, સિમ્બોલ, ગણિત, કોડ.",
        (5, "headline"): "તમારું પેડ\nતમારી શૈલી",
        (5, "subline"): "દરેક ક્ષણ માટે થીમ.",
    },
    "he": {
        "app_subtitle": "מקלדת מספרים",
        "footer_left": "ללא מנוי עבור Pro.",
        "footer_right": "עובד בכל אפליקציה",
        (0, "headline"): "מספרים\nבלי\nעיכובים",
        (0, "subline"): "לוח מספרים אמיתי בכל אפליקציה.",
        (1, "headline"): "טפסים\nמהירים יותר",
        (1, "subline"): "מספרי כרטיס, קודים, סכומים.",
        (2, "headline"): "מס וטיפ\nבנגיעה אחת",
        (2, "subline"): "לחיצה ארוכה על % לחישוב סכומים.",
        (3, "headline"): "הדבקת\nמספרים\nאחרונים",
        (3, "subline"): "היסטוריית הלוח נשארת במכשיר.",
        (4, "headline"): "חבילות Pro\nלעבודה",
        (4, "subline"): "פיננסים, סמלים, מתמטיקה, קוד.",
        (5, "headline"): "הלוח שלך\nהסגנון שלך",
        (5, "subline"): "ערכות נושא לכל רגע.",
    },
    "hr": {
        "app_subtitle": "Numerička tipkovnica",
        "footer_left": "Bez pretplate za Pro.",
        "footer_right": "Radi u svakoj aplikaciji",
        (0, "headline"): "Brojevi\nbez\nkašnjenja",
        (0, "subline"): "Pravi numpad u svakoj aplikaciji.",
        (1, "headline"): "Brže\nispunjavanje\nobrazaca",
        (1, "subline"): "Brojevi kartica, kodovi, ukupno.",
        (2, "headline"): "Porez i\nnapojnica",
        (2, "subline"): "Dugi pritisak na % za izračun.",
        (3, "headline"): "Zalijepite\nnedavne\nbrojeve",
        (3, "subline"): "Povijest međuspremnika ostaje lokalno.",
        (4, "headline"): "Pro paketi\nza posao",
        (4, "subline"): "Financije, simboli, matematika, kôd.",
        (5, "headline"): "Tvoj numpad\ntvoj stil",
        (5, "subline"): "Teme za svaki trenutak.",
    },
    "hu": {
        "app_subtitle": "Számbillentyűzet",
        "footer_left": "Nincs előfizetés a Pro-hoz.",
        "footer_right": "Minden appban működik",
        (0, "headline"): "Számok\nkéslekedés\nnélkül",
        (0, "subline"): "Valódi számbillentyűzet minden appban.",
        (1, "headline"): "Gyorsabb\nűrlapok",
        (1, "subline"): "Kártyaszámok, kódok, összegek.",
        (2, "headline"): "Adó és\nborravaló",
        (2, "subline"): "Nyomja hosszan a %-ot a számításhoz.",
        (3, "headline"): "Illessze be\na legutóbbi\nszámokat",
        (3, "subline"): "A vágólap-előzmények az eszközön maradnak.",
        (4, "headline"): "Pro csomagok\nmunkához",
        (4, "subline"): "Pénzügy, szimbólumok, matek, kód.",
        (5, "headline"): "A te numpad\na te stílusod",
        (5, "subline"): "Témák minden pillanatra.",
    },
    "id": {
        "app_subtitle": "Keyboard Angka",
        "footer_left": "Tanpa langganan untuk Pro.",
        "footer_right": "Berfungsi di semua aplikasi",
        (0, "headline"): "Angka\ntanpa\nhambatan",
        (0, "subline"): "Numpad nyata di setiap aplikasi.",
        (1, "headline"): "Formulir\nlebih cepat",
        (1, "subline"): "Nomor kartu, kode, total.",
        (2, "headline"): "Pajak dan tip\nsatu ketukan",
        (2, "subline"): "Tekan lama % untuk menghitung total.",
        (3, "headline"): "Tempel angka\nterbaru",
        (3, "subline"): "Riwayat clipboard tetap di perangkat.",
        (4, "headline"): "Paket Pro\nuntuk kerja",
        (4, "subline"): "Keuangan, simbol, matematika, kode.",
        (5, "headline"): "Numpad kamu\ngaya kamu",
        (5, "subline"): "Tema yang cocok untuk setiap momen.",
    },
    "it": {
        "app_subtitle": "Tastierino Numerico",
        "footer_left": "Nessun abbonamento per Pro.",
        "footer_right": "Funziona in ogni app",
        (0, "headline"): "Numeri\nsenza\nritardi",
        (0, "subline"): "Un vero tastierino numerico in ogni app.",
        (1, "headline"): "Moduli\npiù veloci",
        (1, "subline"): "Numeri di carta, codici, totali.",
        (2, "headline"): "Tasse e\nmancia",
        (2, "subline"): "Tieni premuto % per calcolare i totali.",
        (3, "headline"): "Incolla\nnumeri\nrecenti",
        (3, "subline"): "La cronologia degli appunti resta locale.",
        (4, "headline"): "Pacchetti Pro\nper il lavoro",
        (4, "subline"): "Finanza, simboli, matematica, codice.",
        (5, "headline"): "Il tuo numpad\nil tuo stile",
        (5, "subline"): "Temi per ogni momento.",
    },
    "kn-IN": {
        "app_subtitle": "ನಂಬರ್ ಪ್ಯಾಡ್ ಕೀಬೋರ್ಡ್",
        "footer_left": "Pro ಗೆ ಸಬ್‌ಸ್ಕ್ರಿಪ್ಶನ್ ಇಲ್ಲ.",
        "footer_right": "ಯಾವುದೇ ಆ್ಯಪ್‌ನಲ್ಲಿ ಕೆಲಸ ಮಾಡುತ್ತದೆ",
        (0, "headline"): "ವಿಳಂಬವಿಲ್ಲದೆ\nಸಂಖ್ಯೆಗಳು",
        (0, "subline"): "ಪ್ರತಿ ಆ್ಯಪ್‌ನಲ್ಲಿ ನಿಜವಾದ ನಂಬರ್ ಪ್ಯಾಡ್.",
        (1, "headline"): "ವೇಗವಾಗಿ\nಫಾರ್ಮ್ ಭರ್ತಿ",
        (1, "subline"): "ಕಾರ್ಡ್ ನಂಬರ್, ಕೋಡ್, ಮೊತ್ತ.",
        (2, "headline"): "ತೆರಿಗೆ ಮತ್ತು\nಟಿಪ್",
        (2, "subline"): "ಮೊತ್ತಕ್ಕೆ % ಉದ್ದವಾಗಿ ಒತ್ತಿ.",
        (3, "headline"): "ಇತ್ತೀಚಿನ\nಸಂಖ್ಯೆಗಳನ್ನು\nಅಂಟಿಸಿ",
        (3, "subline"): "ಕ್ಲಿಪ್‌ಬೋರ್ಡ್ ಇತಿಹಾಸ ಸಾಧನದಲ್ಲೇ ಇರುತ್ತದೆ.",
        (4, "headline"): "ಕೆಲಸಕ್ಕೆ\nPro ಪ್ಯಾಕ್",
        (4, "subline"): "ಫೈನಾನ್ಸ್, ಚಿಹ್ನೆ, ಗಣಿತ, ಕೋಡ್.",
        (5, "headline"): "ನಿಮ್ಮ ಪ್ಯಾಡ್\nನಿಮ್ಮ ಶೈಲಿ",
        (5, "subline"): "ಪ್ರತಿ ಕ್ಷಣಕ್ಕೆ ಥೀಮ್.",
    },
    "ml-IN": {
        "app_subtitle": "നമ്പർ പാഡ് കീബോർഡ്",
        "footer_left": "Pro-യ്ക്ക് സബ്‌സ്ക്രിപ്ഷൻ ഇല്ല.",
        "footer_right": "ഏത് ആപ്പിലും പ്രവർത്തിക്കും",
        (0, "headline"): "കാലതാമസം\nഇല്ലാതെ\nനമ്പറുകൾ",
        (0, "subline"): "എല്ലാ ആപ്പിലും യഥാർത്ഥ നമ്പർ പാഡ്.",
        (1, "headline"): "വേഗത്തിൽ\nഫോം നിറയ്ക്കൂ",
        (1, "subline"): "കാർഡ് നമ്പർ, കോഡ്, ആകെത്തുക.",
        (2, "headline"): "നികുതിയും\nടിപ്പും",
        (2, "subline"): "ആകെത്തുകയ്ക്ക് % ദീർഘമായി അമർത്തുക.",
        (3, "headline"): "സമീപകാല\nനമ്പറുകൾ\nഒട്ടിക്കൂ",
        (3, "subline"): "ക്ലിപ്ബോർഡ് ചരിത്രം ഉപകരണത്തിൽ തന്നെ.",
        (4, "headline"): "ജോലിക്ക്\nPro പാക്ക്",
        (4, "subline"): "ഫിനാൻസ്, ചിഹ്നങ്ങൾ, ഗണിതം, കോഡ്.",
        (5, "headline"): "നിങ്ങളുടെ പാഡ്\nനിങ്ങളുടെ ശൈലി",
        (5, "subline"): "ഓരോ നിമിഷത്തിനും തീം.",
    },
    "mr-IN": {
        "app_subtitle": "नंबर पॅड कीबोर्ड",
        "footer_left": "Pro साठी सदस्यता नाही.",
        "footer_right": "कोणत्याही ॲपमध्ये चालते",
        (0, "headline"): "विलंब न\nहोता\nसंख्या",
        (0, "subline"): "प्रत्येक ॲपमध्ये खरा नंबर पॅड.",
        (1, "headline"): "जलद\nफॉर्म भरा",
        (1, "subline"): "कार्ड नंबर, कोड, एकूण.",
        (2, "headline"): "कर आणि\nटिप",
        (2, "subline"): "एकूणासाठी % दीर्घ दाबा.",
        (3, "headline"): "अलीकडील\nसंख्या\nपेस्ट करा",
        (3, "subline"): "क्लिपबोर्ड इतिहास डिव्हाइसवर राहतो.",
        (4, "headline"): "कामासाठी\nPro पॅक",
        (4, "subline"): "फायनान्स, चिन्हे, गणित, कोड.",
        (5, "headline"): "तुमचा पॅड\nतुमची शैली",
        (5, "subline"): "प्रत्येक क्षणासाठी थीम.",
    },
    "ms": {
        "app_subtitle": "Papan Kekunci Nombor",
        "footer_left": "Tiada langganan untuk Pro.",
        "footer_right": "Berfungsi di semua aplikasi",
        (0, "headline"): "Nombor\ntanpa\nkelambatan",
        (0, "subline"): "Numpad sebenar dalam setiap aplikasi.",
        (1, "headline"): "Borang\nlebih pantas",
        (1, "subline"): "Nombor kad, kod, jumlah.",
        (2, "headline"): "Cukai dan tip\nsatu ketukan",
        (2, "subline"): "Tekan lama % untuk mengira jumlah.",
        (3, "headline"): "Tampal\nnombor\nterkini",
        (3, "subline"): "Sejarah papan klip kekal dalam peranti.",
        (4, "headline"): "Pek Pro\nuntuk kerja",
        (4, "subline"): "Kewangan, simbol, matematik, kod.",
        (5, "headline"): "Numpad anda\ngaya anda",
        (5, "subline"): "Tema yang sesuai untuk setiap saat.",
    },
    "nl-NL": {
        "app_subtitle": "Numeriek Toetsenbord",
        "footer_left": "Geen abonnement voor Pro.",
        "footer_right": "Werkt in elke app",
        (0, "headline"): "Cijfers\nzonder\nvertraging",
        (0, "subline"): "Een echt numeriek toetsenbord in elke app.",
        (1, "headline"): "Snellere\nformulieren",
        (1, "subline"): "Kaartnummers, codes, totalen.",
        (2, "headline"): "Belasting\nen fooi",
        (2, "subline"): "Houd % ingedrukt voor totalen.",
        (3, "headline"): "Plak recente\nnummers",
        (3, "subline"): "Klembordgeschiedenis blijft op je toestel.",
        (4, "headline"): "Pro-pakketten\nvoor werk",
        (4, "subline"): "Financiën, symbolen, wiskunde, code.",
        (5, "headline"): "Jouw numpad\njouw stijl",
        (5, "subline"): "Thema's voor elk moment.",
    },
    "no": {
        "app_subtitle": "Numerisk tastatur",
        "footer_left": "Intet abonnement for Pro.",
        "footer_right": "Fungerer i alle apper",
        (0, "headline"): "Tall uten\nforsinkelser",
        (0, "subline"): "Et ekte talltastatur i hver app.",
        (1, "headline"): "Raskere\nskjemaer",
        (1, "subline"): "Kortnumre, koder, totaler.",
        (2, "headline"): "Skatt og\ntips",
        (2, "subline"): "Hold % for å beregne totaler.",
        (3, "headline"): "Lim inn\nnylige\ntall",
        (3, "subline"): "Utklippstavlen forblir på enheten.",
        (4, "headline"): "Pro-pakker\nfor jobb",
        (4, "subline"): "Finans, symboler, matte, kode.",
        (5, "headline"): "Ditt tastatur\ndin stil",
        (5, "subline"): "Temaer som passer øyeblikket.",
    },
    "or-IN": {
        "app_subtitle": "ନମ୍ବର ପ୍ୟାଡ୍ କୀବୋର୍ଡ",
        "footer_left": "Pro ପାଇଁ ସଦସ୍ୟତା ନାହିଁ.",
        "footer_right": "ଯେକୌଣସି ଆପରେ କାମ କରେ",
        (0, "headline"): "ବିଳମ୍ବ ବିନା\nସଂଖ୍ୟା\nଦାଖଲ",
        (0, "subline"): "ପ୍ରତ୍ୟେକ ଆପରେ ଏକ ପ୍ରକୃତ ନମ୍ବର ପ୍ୟାଡ୍.",
        (1, "headline"): "ଦ୍ରୁତ\nଫର୍ମ ପୂରଣ",
        (1, "subline"): "କାର୍ଡ ନମ୍ବର, କୋଡ୍, ମୋଟ.",
        (2, "headline"): "ଟ୍ୟାକ୍ସ ଓ\nଟିପ୍",
        (2, "subline"): "ମୋଟ ପାଇଁ % ଦୀର୍ଘ ଚାପନ୍ତୁ.",
        (3, "headline"): "ସାମ୍ପ୍ରତିକ\nସଂଖ୍ୟା\nପେଷ୍ଟ କରନ୍ତୁ",
        (3, "subline"): "କ୍ଲିପବୋର୍ଡ ଇତିହାସ ଡିଭାଇସରେ ରହେ.",
        (4, "headline"): "କାମ ପାଇଁ\nPro ପ୍ୟାକ",
        (4, "subline"): "ଫାଇନାନ୍ସ, ଚିହ୍ନ, ଗଣିତ, କୋଡ୍.",
        (5, "headline"): "ଆପଣଙ୍କ ପ୍ୟାଡ୍\nଆପଣଙ୍କ ଶୈଳୀ",
        (5, "subline"): "ପ୍ରତ୍ୟେକ ମୁହୂର୍ତ୍ତ ପାଇଁ ଥିମ୍.",
    },
    "pa-IN": {
        "app_subtitle": "ਨੰਬਰ ਪੈਡ ਕੀਬੋਰਡ",
        "footer_left": "Pro ਲਈ ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਨਹੀਂ.",
        "footer_right": "ਕਿਸੇ ਵੀ ਐਪ ਵਿੱਚ ਕੰਮ ਕਰੇ",
        (0, "headline"): "ਬਿਨਾਂ ਦੇਰੀ\nਨੰਬਰ\nਦਾਖਲ ਕਰੋ",
        (0, "subline"): "ਹਰ ਐਪ ਵਿੱਚ ਅਸਲੀ ਨੰਬਰ ਪੈਡ.",
        (1, "headline"): "ਤੇਜ਼\nਫਾਰਮ ਭਰੋ",
        (1, "subline"): "ਕਾਰਡ ਨੰਬਰ, ਕੋਡ, ਕੁੱਲ.",
        (2, "headline"): "ਟੈਕਸ ਅਤੇ\nਟਿਪ",
        (2, "subline"): "ਕੁੱਲ ਲਈ % ਲੰਬਾ ਦਬਾਓ.",
        (3, "headline"): "ਤਾਜ਼ਾ ਨੰਬਰ\nਪੇਸਟ ਕਰੋ",
        (3, "subline"): "ਕਲਿੱਪਬੋਰਡ ਇਤਿਹਾਸ ਡਿਵਾਈਸ ਤੇ ਰਹਿੰਦਾ ਹੈ.",
        (4, "headline"): "ਕੰਮ ਲਈ\nPro ਪੈਕ",
        (4, "subline"): "ਫਾਇਨੈਂਸ, ਚਿੰਨ੍ਹ, ਗਣਿਤ, ਕੋਡ.",
        (5, "headline"): "ਤੁਹਾਡਾ ਪੈਡ\nਤੁਹਾਡੀ ਸ਼ੈਲੀ",
        (5, "subline"): "ਹਰ ਪਲ ਲਈ ਥੀਮ.",
    },
    "pl": {
        "app_subtitle": "Klawiatura Numeryczna",
        "footer_left": "Bez subskrypcji na Pro.",
        "footer_right": "Działa w każdej aplikacji",
        (0, "headline"): "Liczby\nbez\nopóźnień",
        (0, "subline"): "Prawdziwy numpad w każdej aplikacji.",
        (1, "headline"): "Szybsze\nformularze",
        (1, "subline"): "Numery kart, kody, sumy.",
        (2, "headline"): "Podatek\ni napiwek",
        (2, "subline"): "Przytrzymaj % by obliczyć sumy.",
        (3, "headline"): "Wklej\nostatnie\nliczby",
        (3, "subline"): "Historia schowka zostaje na urządzeniu.",
        (4, "headline"): "Pakiety Pro\ndo pracy",
        (4, "subline"): "Finanse, symbole, matematyka, kod.",
        (5, "headline"): "Twój numpad\ntwój styl",
        (5, "subline"): "Motywy na każdą chwilę.",
    },
    "pt-PT": {
        "app_subtitle": "Teclado Numérico",
        "footer_left": "Sem subscrição para Pro.",
        "footer_right": "Funciona em qualquer app",
        (0, "headline"): "Números\nsem\natrasos",
        (0, "subline"): "Um teclado numérico real em cada app.",
        (1, "headline"): "Formulários\nmais rápidos",
        (1, "subline"): "Números de cartão, códigos, totais.",
        (2, "headline"): "Imposto e\ngorjeta",
        (2, "subline"): "Prima longamente o % para totais.",
        (3, "headline"): "Cole números\nrecentes",
        (3, "subline"): "Histórico da área de transferência local.",
        (4, "headline"): "Pacotes Pro\npara o trabalho",
        (4, "subline"): "Finanças, símbolos, matemática, código.",
        (5, "headline"): "O seu numpad\no seu estilo",
        (5, "subline"): "Temas que combinam com o momento.",
    },
    "ro": {
        "app_subtitle": "Tastatură Numerică",
        "footer_left": "Fără abonament pentru Pro.",
        "footer_right": "Funcționează în orice aplicație",
        (0, "headline"): "Numere\nfără\nîntârzieri",
        (0, "subline"): "Un numpad real în fiecare aplicație.",
        (1, "headline"): "Formulare\nmai rapide",
        (1, "subline"): "Numere de card, coduri, totaluri.",
        (2, "headline"): "Taxe și\nbacșiș",
        (2, "subline"): "Apasă lung pe % pentru totaluri.",
        (3, "headline"): "Lipește\nnumere\nrecente",
        (3, "subline"): "Istoricul clipboard-ului rămâne local.",
        (4, "headline"): "Pachete Pro\npentru muncă",
        (4, "subline"): "Finanțe, simboluri, matematică, cod.",
        (5, "headline"): "Numpad-ul tău\nstilul tău",
        (5, "subline"): "Teme pentru fiecare moment.",
    },
    "ru": {
        "app_subtitle": "Цифровая клавиатура",
        "footer_left": "Без подписки для Pro.",
        "footer_right": "Работает в любом приложении",
        (0, "headline"): "Цифры\nбез\nзадержек",
        (0, "subline"): "Настоящий нампад в каждом приложении.",
        (1, "headline"): "Быстрые\nформы",
        (1, "subline"): "Номера карт, коды, итоги.",
        (2, "headline"): "Налог и\nчаевые",
        (2, "subline"): "Удерживайте % для расчёта итогов.",
        (3, "headline"): "Вставьте\nнедавние\nцифры",
        (3, "subline"): "Буфер обмена остаётся на устройстве.",
        (4, "headline"): "Pro-пакеты\nдля работы",
        (4, "subline"): "Финансы, символы, математика, код.",
        (5, "headline"): "Ваш нампад\nваш стиль",
        (5, "subline"): "Темы на каждый момент.",
    },
    "sk": {
        "app_subtitle": "Numerická klávesnica",
        "footer_left": "Bez predplatného na Pro.",
        "footer_right": "Funguje v každej aplikácii",
        (0, "headline"): "Čísla\nbez\nzdržania",
        (0, "subline"): "Skutočný numpad v každej aplikácii.",
        (1, "headline"): "Rýchlejšie\nformuláre",
        (1, "subline"): "Čísla kariet, kódy, súčty.",
        (2, "headline"): "Daň a\nprepitné",
        (2, "subline"): "Podržte % pre výpočet súčtov.",
        (3, "headline"): "Prilepte\nnedávne\nčísla",
        (3, "subline"): "História schránky zostáva v zariadení.",
        (4, "headline"): "Pro balíčky\npre prácu",
        (4, "subline"): "Financie, symboly, matematika, kód.",
        (5, "headline"): "Váš numpad\nváš štýl",
        (5, "subline"): "Motívy pre každý okamih.",
    },
    "sl-SI": {
        "app_subtitle": "Številska tipkovnica",
        "footer_left": "Brez naročnine za Pro.",
        "footer_right": "Deluje v vsaki aplikaciji",
        (0, "headline"): "Številke\nbrez\nzamud",
        (0, "subline"): "Pravi numpad v vsaki aplikaciji.",
        (1, "headline"): "Hitrejši\nobrazci",
        (1, "subline"): "Številke kartic, kode, vsote.",
        (2, "headline"): "Davek in\nnapitnina",
        (2, "subline"): "Držite % za izračun vsot.",
        (3, "headline"): "Prilepite\nnedavne\nštevilke",
        (3, "subline"): "Zgodovina odložišča ostane na napravi.",
        (4, "headline"): "Pro paketi\nza delo",
        (4, "subline"): "Finance, simboli, matematika, koda.",
        (5, "headline"): "Vaš numpad\nvaš slog",
        (5, "subline"): "Teme za vsak trenutek.",
    },
    "sv": {
        "app_subtitle": "Numeriskt tangentbord",
        "footer_left": "Inget abonnemang för Pro.",
        "footer_right": "Fungerar i alla appar",
        (0, "headline"): "Siffror\nutan\nfördröjning",
        (0, "subline"): "Ett riktigt numeriskt tangentbord.",
        (1, "headline"): "Snabbare\nformulär",
        (1, "subline"): "Kortnummer, koder, summor.",
        (2, "headline"): "Skatt och\ndricks",
        (2, "subline"): "Håll in % för att beräkna summor.",
        (3, "headline"): "Klistra in\nsenaste\nsiffror",
        (3, "subline"): "Urklippshistorik stannar på enheten.",
        (4, "headline"): "Pro-paket\nför jobb",
        (4, "subline"): "Finans, symboler, matte, kod.",
        (5, "headline"): "Ditt numpad\ndin stil",
        (5, "subline"): "Teman som passar stunden.",
    },
    "ta-IN": {
        "app_subtitle": "எண் பேட் விசைப்பலகை",
        "footer_left": "Pro-க்கு சந்தா இல்லை.",
        "footer_right": "எந்த ஆப்பிலும் செயல்படும்",
        (0, "headline"): "தாமதமின்றி\nஎண்கள்\nஉள்ளிடுக",
        (0, "subline"): "ஒவ்வொரு ஆப்பிலும் உண்மையான நம்பர் பேட்.",
        (1, "headline"): "வேகமாக\nபடிவம் நிரப்பு",
        (1, "subline"): "கார்டு எண், குறியீடு, மொத்தம்.",
        (2, "headline"): "வரி மற்றும்\nடிப்",
        (2, "subline"): "மொத்தத்திற்கு % நீண்ட நேரம் அழுத்துக.",
        (3, "headline"): "சமீபத்திய\nஎண்களை\nஒட்டுக",
        (3, "subline"): "கிளிப்போர்டு வரலாறு சாதனத்தில் இருக்கும்.",
        (4, "headline"): "வேலைக்கு\nPro பேக்",
        (4, "subline"): "நிதி, குறியீடுகள், கணிதம், கோட்.",
        (5, "headline"): "உங்கள் பேட்\nஉங்கள் பாணி",
        (5, "subline"): "ஒவ்வொரு தருணத்திற்கும் தீம்.",
    },
    "te-IN": {
        "app_subtitle": "నంబర్ ప్యాడ్ కీబోర్డ్",
        "footer_left": "Pro కి సబ్‌స్క్రిప్షన్ లేదు.",
        "footer_right": "ఏ యాప్‌లోనైనా పని చేస్తుంది",
        (0, "headline"): "ఆలస్యం\nలేకుండా\nనంబర్లు",
        (0, "subline"): "ప్రతి యాప్‌లో నిజమైన నంబర్ ప్యాడ్.",
        (1, "headline"): "వేగంగా\nఫారమ్ నింపు",
        (1, "subline"): "కార్డ్ నంబర్, కోడ్, మొత్తం.",
        (2, "headline"): "పన్ను మరియు\nటిప్",
        (2, "subline"): "మొత్తానికి % దీర్ఘంగా నొక్కండి.",
        (3, "headline"): "ఇటీవలి\nనంబర్లు\nపేస్ట్ చేయండి",
        (3, "subline"): "క్లిప్‌బోర్డ్ చరిత్ర డివైస్‌లో ఉంటుంది.",
        (4, "headline"): "పనికి\nPro ప్యాక్",
        (4, "subline"): "ఫైనాన్స్, చిహ్నాలు, గణితం, కోడ్.",
        (5, "headline"): "మీ ప్యాడ్\nమీ శైలి",
        (5, "subline"): "ప్రతి క్షణానికి థీమ్.",
    },
    "tr": {
        "app_subtitle": "Sayısal Tuş Takımı",
        "footer_left": "Pro için abonelik yok.",
        "footer_right": "Her uygulamada çalışır",
        (0, "headline"): "Yavaşlama\nolmadan\nrakamlar",
        (0, "subline"): "Her uygulamada gerçek bir sayısal tuş takımı.",
        (1, "headline"): "Daha hızlı\nformlar",
        (1, "subline"): "Kart numaraları, kodlar, toplamlar.",
        (2, "headline"): "Vergi ve\nbahşiş",
        (2, "subline"): "Toplam için % tuşuna uzun basın.",
        (3, "headline"): "Son sayıları\nyapıştır",
        (3, "subline"): "Pano geçmişi cihazda kalır.",
        (4, "headline"): "İş için\nPro paketler",
        (4, "subline"): "Finans, semboller, matematik, kod.",
        (5, "headline"): "Senin tuşların\nsenin tarzın",
        (5, "subline"): "Her ana uygun temalar.",
    },
    "uk": {
        "app_subtitle": "Цифрова клавіатура",
        "footer_left": "Без підписки для Pro.",
        "footer_right": "Працює в будь-якому додатку",
        (0, "headline"): "Цифри\nбез\nзатримок",
        (0, "subline"): "Справжній нампад у кожному додатку.",
        (1, "headline"): "Швидші\nформи",
        (1, "subline"): "Номери карток, коди, суми.",
        (2, "headline"): "Податок і\nчайові",
        (2, "subline"): "Утримуйте % для розрахунку сум.",
        (3, "headline"): "Вставте\nnедавні\nцифри",
        (3, "subline"): "Буфер обміну залишається на пристрої.",
        (4, "headline"): "Pro-пакети\nдля роботи",
        (4, "subline"): "Фінанси, символи, математика, код.",
        (5, "headline"): "Ваш нампад\nваш стиль",
        (5, "subline"): "Теми на кожну мить.",
    },
    "ur-PK": {
        "app_subtitle": "نمبر پیڈ کی بورڈ",
        "footer_left": "Pro کے لیے سبسکرپشن نہیں.",
        "footer_right": "ہر ایپ میں کام کرے",
        (0, "headline"): "بغیر تاخیر\nنمبر\nدرج کریں",
        (0, "subline"): "ہر ایپ میں اصل نمبر پیڈ.",
        (1, "headline"): "تیز تر\nفارم بھریں",
        (1, "subline"): "کارڈ نمبر، کوڈ، کل.",
        (2, "headline"): "ٹیکس اور\nٹپ",
        (2, "subline"): "کل کے لیے % دیر تک دبائیں.",
        (3, "headline"): "حالیہ نمبر\nپیسٹ کریں",
        (3, "subline"): "کلپ بورڈ ہسٹری ڈیوائس پر رہتی ہے.",
        (4, "headline"): "کام کے لیے\nPro پیک",
        (4, "subline"): "فنانس، علامات، ریاضی، کوڈ.",
        (5, "headline"): "آپ کا پیڈ\nآپ کا انداز",
        (5, "subline"): "ہر لمحے کے لیے تھیم.",
    },
    "vi": {
        "app_subtitle": "Bàn Phím Số",
        "footer_left": "Không cần đăng ký cho Pro.",
        "footer_right": "Hoạt động trong mọi ứng dụng",
        (0, "headline"): "Nhập số\nkhông\nchậm trễ",
        (0, "subline"): "Bàn phím số thật trong mọi ứng dụng.",
        (1, "headline"): "Điền biểu mẫu\nnhanh hơn",
        (1, "subline"): "Số thẻ, mã, tổng cộng.",
        (2, "headline"): "Thuế và\ntiền tip",
        (2, "subline"): "Nhấn giữ % để tính tổng.",
        (3, "headline"): "Dán số\ngần đây",
        (3, "subline"): "Lịch sử clipboard ở trên thiết bị.",
        (4, "headline"): "Gói Pro\ncho công việc",
        (4, "subline"): "Tài chính, ký hiệu, toán, code.",
        (5, "headline"): "Bàn phím bạn\nphong cách\ncủa bạn",
        (5, "subline"): "Giao diện phù hợp mọi khoảnh khắc.",
    },

}


def get_slide_text(slide_idx: int, field: str, locale: str, slide: "Slide") -> str:
    """Return localized text for a slide, falling back to English defaults."""
    loc = LOCALE_TEXT.get(locale, {})
    # Slide-specific fields
    key = (slide_idx, field)
    if key in loc:
        return loc[key]
    # Shared fields (footer_left, footer_right, app_subtitle)
    if field in loc:
        return loc[field]
    # English defaults
    if field == "headline":
        return slide.headline
    if field == "subline":
        return slide.subline
    if field == "footer_left":
        return "No subscription required for Pro."
    if field == "footer_right":
        return "Works in any app"
    if field == "app_subtitle":
        return "Number Pad Keyboard"
    return ""


SLIDES = [
    Slide(
        slug="01-numbers-without-slowdowns",
        source="01-hero.png",
        headline="Numbers\nwithout\nslowdowns",
        subline="A real numpad in every app.",
        top=(238, 249, 255),
        bottom=(198, 236, 227),
        accent=(38, 139, 246),
        phone_width=820,
        phone_y=910,
        phone_x=250,
        scrub_y=1590,
        dark_text=True,
    ),
    Slide(
        slug="02-faster-forms",
        source="02-checkout.png",
        headline="Faster\nforms",
        subline="Card numbers, codes, totals.",
        top=(24, 126, 224),
        bottom=(11, 86, 167),
        accent=(101, 232, 226),
        phone_width=790,
        phone_y=920,
        phone_x=265,
        scrub_y=1360,
    ),
    Slide(
        slug="03-tax-and-tip",
        source="03-taxtip.png",
        headline="Tax and tip\nin one tap",
        subline="Long-press % when totals matter.",
        top=(246, 250, 252),
        bottom=(255, 239, 220),
        accent=(255, 149, 0),
        phone_width=800,
        phone_y=880,
        phone_x=260,
        dark_text=True,
    ),
    Slide(
        slug="04-paste-recent-numbers",
        source="04-clipboard.png",
        headline="Paste recent\nnumbers",
        subline="Clipboard history stays on-device.",
        top=(8, 120, 111),
        bottom=(7, 63, 92),
        accent=(85, 223, 168),
        phone_width=790,
        phone_y=910,
        phone_x=265,
    ),
    Slide(
        slug="05-pro-packs-for-work",
        source="08-dark-programmer.png",
        headline="Pro packs\nfor work",
        subline="Finance, symbols, math, code.",
        top=(26, 29, 41),
        bottom=(73, 57, 117),
        accent=(144, 118, 255),
        phone_width=790,
        phone_y=905,
        phone_x=265,
    ),
    Slide(
        slug="06-your-numpad-your-style",
        source="05-themes.png",
        headline="Your numpad\nyour style",
        subline="Themes that fit the moment.",
        top=(255, 249, 240),
        bottom=(230, 247, 255),
        accent=(255, 59, 48),
        phone_width=800,
        phone_y=900,
        phone_x=260,
        dark_text=True,
    ),
]


# ── Locale-to-font mapping ───────────────────────────────────────────
# CJK and complex-script locales need specific fonts that cover their glyphs.
# On macOS the system fonts handle everything; on Linux we need explicit paths.

_LOCALE_FONT_CACHE: dict[tuple[str, int, bool], ImageFont.FreeTypeFont] = {}

# CJK font index mapping for NotoSansCJK .ttc collections:
#   0=JP, 1=KR, 2=SC, 3=TC, 4=HK  (same order for Bold and Regular)
_CJK_TTC_INDEX: dict[str, int] = {
    "ja": 0,
    "ko": 1,
    "zh-Hans": 2,
    "zh-Hant": 3,
}

def _needs_cjk_font(locale: str) -> bool:
    return locale in _CJK_TTC_INDEX

# Map locale codes to Noto Sans font family names (files in marketing/assets/)
_LOCALE_SCRIPT_FONT: dict[str, str] = {
    "th": "NotoSansThai",
    "hi": "NotoSansDevanagari",
    "mr-IN": "NotoSansDevanagari",   # Marathi uses Devanagari
    "bn-BD": "NotoSansBengali",
    "gu-IN": "NotoSansGujarati",
    "he": "NotoSansHebrew",
    "kn-IN": "NotoSansKannada",
    "ml-IN": "NotoSansMalayalam",
    "or-IN": "NotoSansOriya",
    "pa-IN": "NotoSansGurmukhi",
    "ta-IN": "NotoSansTamil",
    "te-IN": "NotoSansTelugu",
    "ar-SA": "NotoSansArabic",
    "ur-PK": "NotoSansArabic",       # Urdu uses Arabic script
    "el": "NotoSans",                # Greek — NotoSans covers Greek + Cyrillic + Latin
    "ru": "NotoSans",                # Cyrillic
    "uk": "NotoSans",                # Ukrainian (Cyrillic)
}

def _needs_script_font(locale: str) -> bool:
    return locale in _LOCALE_SCRIPT_FONT


def font(size: int, bold: bool = False, locale: str = "en") -> ImageFont.FreeTypeFont:
    cache_key = (locale, size, bold)
    if cache_key in _LOCALE_FONT_CACHE:
        return _LOCALE_FONT_CACHE[cache_key]

    result = _load_font(size, bold, locale)
    _LOCALE_FONT_CACHE[cache_key] = result
    return result


def _load_font(size: int, bold: bool, locale: str) -> ImageFont.FreeTypeFont:
    # ── CJK locales: use NotoSansCJK .ttc with correct index ──
    if _needs_cjk_font(locale):
        idx = _CJK_TTC_INDEX[locale]
        cjk_candidates = [
            # Linux
            "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc" if bold else "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
            # macOS (Homebrew or system)
            "/System/Library/Fonts/LanguageSupport/PingFang.ttc",
            "/System/Library/Fonts/Hiragino Sans GB.ttc",
            # Broad fallback
            "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf",
        ]
        for candidate in cjk_candidates:
            try:
                ttc_index = idx if candidate.endswith(".ttc") and "Noto" in candidate else 0
                return ImageFont.truetype(candidate, size, index=ttc_index)
            except OSError:
                continue

    # ── Non-Latin script locales: use bundled Noto Sans fonts ──
    if _needs_script_font(locale):
        family = _LOCALE_SCRIPT_FONT[locale]
        _ASSETS = ROOT / "marketing" / "assets"
        weight = "Bold" if bold else "Regular"
        script_candidates = [
            str(_ASSETS / f"{family}-{weight}.ttf"),
            f"/usr/share/fonts/truetype/noto/{family}-{weight}.ttf",
            f"/System/Library/Fonts/LanguageSupport/{family}.ttc",
            "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf",
        ]
        for candidate in script_candidates:
            try:
                return ImageFont.truetype(candidate, size, index=0)
            except OSError:
                continue

    # ── Latin-script locales (en, de, fr, es, pt, etc.) ──
    candidates = [
        # macOS
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        # Linux
        "/usr/share/fonts/truetype/carlito/Carlito-Bold.ttf" if bold else "/usr/share/fonts/truetype/carlito/Carlito-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size, index=1 if bold and candidate.endswith(".ttc") else 0)
        except OSError:
            continue
    return ImageFont.load_default()


def gradient(top: tuple[int, int, int], bottom: tuple[int, int, int], w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), top)
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        row = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(w):
            px[x, y] = row
    return img.convert("RGBA")


def draw_key_pattern(draw: ImageDraw.ImageDraw, slide: Slide) -> None:
    labels = ["#", "2", "0x", "+", "%", "3"]
    positions = [(930, 300), (1036, 720), (74, 1240), (1030, 1420), (1028, 2350), (82, 2420)]
    fill = (255, 255, 255, 44 if not slide.dark_text else 82)
    outline = slide.accent + (80,)
    key_font = font(82, bold=True)
    for index, (label, (x, y)) in enumerate(zip(labels, positions)):
        w = 188 if len(label) <= 1 else 226
        h = 150
        radius = 36
        draw.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=fill, outline=outline, width=3)
        box = draw.textbbox((0, 0), label, font=key_font)
        tx = x + (w - (box[2] - box[0])) / 2
        ty = y + (h - (box[3] - box[1])) / 2 - 8
        alpha = 100 if slide.dark_text else 128
        draw.text((tx, ty), label, font=key_font, fill=slide.accent + (alpha,))


def scrub_capture(img: Image.Image, y: int | None) -> Image.Image:
    if y is None:
        return img
    cleaned = img.copy()
    d = ImageDraw.Draw(cleaned)
    x1, y1, x2, y2 = 470, y, 850, y + 118
    d.rounded_rectangle((x1, y1, x2, y2), radius=58, fill=(255, 255, 255, 255))
    return cleaned


def make_phone(source: Path, width: int, scrub_y: int | None) -> Image.Image:
    mockup = Image.open(MOCKUP).convert("RGBA")
    shot = scrub_capture(Image.open(source).convert("RGBA"), scrub_y)
    scale = width / mockup.width
    phone = mockup.resize((width, round(mockup.height * scale)), Image.Resampling.LANCZOS)

    sc_l = round((52 / 1022) * phone.width)
    sc_t = round((46 / 2082) * phone.height)
    sc_w = round((918 / 1022) * phone.width)
    sc_h = round((1990 / 2082) * phone.height)

    screen = shot.resize((sc_w, sc_h), Image.Resampling.LANCZOS)
    mask = Image.new("L", (sc_w, sc_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sc_w, sc_h), radius=round(sc_w * 0.13), fill=255)
    phone.paste(screen, (sc_l, sc_t), mask)
    return phone


def shadow_layer(item: Image.Image, xy: tuple[int, int], canvas_size: tuple[int, int]) -> Image.Image:
    shadow = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    shadow.alpha_composite(item, (xy[0] + 16, xy[1] + 28))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    shadow.putalpha(shadow.getchannel("A").point(lambda p: min(110, p)))
    return shadow


def draw_multiline(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], font_obj: ImageFont.FreeTypeFont, fill: tuple[int, int, int, int], line_gap: int) -> int:
    x, y = xy
    for line in text.splitlines():
        draw.text((x, y), line, font=font_obj, fill=fill)
        bbox = draw.textbbox((x, y), line, font=font_obj)
        y += (bbox[3] - bbox[1]) + line_gap
    return y


def render_slide(slide: Slide, locale: str = "en", slide_idx: int = 0) -> Image.Image:
    canvas = gradient(slide.top, slide.bottom, CANVAS_W, CANVAS_H)
    d = ImageDraw.Draw(canvas, "RGBA")
    draw_key_pattern(d, slide)

    text_color = (22, 32, 46, 255) if slide.dark_text else (255, 255, 255, 255)
    muted = (63, 76, 92, 230) if slide.dark_text else (235, 247, 255, 230)

    icon = Image.open(ICON).convert("RGBA").resize((136, 136), Image.Resampling.LANCZOS)
    icon_mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(icon_mask).rounded_rectangle((0, 0, icon.width, icon.height), radius=30, fill=255)
    d.rounded_rectangle((86, 106, 236, 256), radius=34, fill=(255, 255, 255, 92 if not slide.dark_text else 190))
    canvas.paste(icon, (93, 113), icon_mask)
    d.text((266, 142), "NumPad", font=font(48, bold=True), fill=text_color)
    app_sub = get_slide_text(slide_idx, "app_subtitle", locale, slide)
    d.text((266, 202), app_sub, font=font(30, locale=locale), fill=muted)

    headline = get_slide_text(slide_idx, "headline", locale, slide)
    subline = get_slide_text(slide_idx, "subline", locale, slide)
    draw_multiline(d, headline, (86, 340), font(128, bold=True, locale=locale), text_color, 14)
    d.text((90, 730), subline, font=font(38, locale=locale), fill=muted)

    phone = make_phone(RAW / slide.source, slide.phone_width, slide.scrub_y)
    xy = (slide.phone_x, slide.phone_y)
    canvas.alpha_composite(shadow_layer(phone, xy, canvas.size))
    canvas.alpha_composite(phone, xy)

    footer_left = get_slide_text(slide_idx, "footer_left", locale, slide)
    footer_right = get_slide_text(slide_idx, "footer_right", locale, slide)
    footer_fill = (255, 255, 255, 190) if slide.dark_text else (8, 24, 38, 132)
    footer_color = (24, 48, 74, 230) if slide.dark_text else (255, 255, 255, 238)
    d.rounded_rectangle((86, 2622, 1234, 2724), radius=50, fill=footer_fill)
    footer_font = font(34, bold=True, locale=locale)
    d.text((132, 2654), footer_left, font=footer_font, fill=footer_color)
    # Right-align footer_right
    fr_box = d.textbbox((0, 0), footer_right, font=footer_font)
    fr_w = fr_box[2] - fr_box[0]
    d.text((1234 - 46 - fr_w, 2654), footer_right, font=footer_font, fill=footer_color)
    return canvas.convert("RGB")


def render_slide_ipad(slide: Slide, locale: str = "en", slide_idx: int = 0) -> Image.Image:
    """Render a slide at iPad 13-inch (2064x2752) proportions.

    Layout is adapted for the wider aspect ratio: text and phone are
    scaled proportionally, and the phone is centred on the wider canvas.
    """
    w, h = IPAD_CANVAS_W, IPAD_CANVAS_H
    sx = w / CANVAS_W          # ~1.564
    sy = h / CANVAS_H          # ~0.960
    s_avg = (sx + sy) / 2      # ~1.262

    canvas = gradient(slide.top, slide.bottom, w, h)
    d = ImageDraw.Draw(canvas, "RGBA")

    # Key pattern — manually positioned for 2064-wide iPad canvas
    labels = ["#", "2", "0x", "+", "%", "3"]
    max_kw = round(226 * s_avg)
    positions_ipad = [
        (w - max_kw - 160, round(280 * sy)),
        (w - max_kw - 80,  round(670 * sy)),
        (round(74 * sx),   round(1150 * sy)),
        (w - max_kw - 100, round(1320 * sy)),
        (w - max_kw - 120, round(2200 * sy)),
        (round(82 * sx),   round(2260 * sy)),
    ]
    fill_kp = (255, 255, 255, 44 if not slide.dark_text else 82)
    outline_kp = slide.accent + (80,)
    key_font_ipad = font(round(82 * s_avg), bold=True)
    for label, (kx, ky) in zip(labels, positions_ipad):
        kw = round((188 if len(label) <= 1 else 226) * s_avg)
        kh = round(150 * s_avg)
        radius = round(36 * s_avg)
        d.rounded_rectangle((kx, ky, kx + kw, ky + kh), radius=radius, fill=fill_kp, outline=outline_kp, width=3)
        box = d.textbbox((0, 0), label, font=key_font_ipad)
        tx = kx + (kw - (box[2] - box[0])) / 2
        ty = ky + (kh - (box[3] - box[1])) / 2 - 8
        alpha = 100 if slide.dark_text else 128
        d.text((tx, ty), label, font=key_font_ipad, fill=slide.accent + (alpha,))

    text_color = (22, 32, 46, 255) if slide.dark_text else (255, 255, 255, 255)
    muted = (63, 76, 92, 230) if slide.dark_text else (235, 247, 255, 230)

    # App icon — scaled
    icon_size = round(136 * s_avg)
    icon = Image.open(ICON).convert("RGBA").resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    icon_mask = Image.new("L", icon.size, 0)
    r_icon = round(30 * s_avg)
    ImageDraw.Draw(icon_mask).rounded_rectangle((0, 0, icon.width, icon.height), radius=r_icon, fill=255)
    ix = round(86 * sx)
    iy = round(106 * sy)
    bg_pad = round(7 * s_avg)
    d.rounded_rectangle(
        (ix - bg_pad, iy - bg_pad, ix + icon_size + bg_pad, iy + icon_size + bg_pad),
        radius=round(34 * s_avg),
        fill=(255, 255, 255, 92 if not slide.dark_text else 190),
    )
    canvas.paste(icon, (ix, iy), icon_mask)
    d.text((ix + icon_size + round(30 * s_avg), iy + round(36 * sy)), "NumPad", font=font(round(48 * s_avg), bold=True), fill=text_color)
    app_sub = get_slide_text(slide_idx, "app_subtitle", locale, slide)
    d.text((ix + icon_size + round(30 * s_avg), iy + round(96 * sy)), app_sub, font=font(round(30 * s_avg), locale=locale), fill=muted)

    # Headline and subline
    headline = get_slide_text(slide_idx, "headline", locale, slide)
    subline = get_slide_text(slide_idx, "subline", locale, slide)
    hl_x = round(86 * sx)
    hl_y = round(340 * sy)
    draw_multiline(d, headline, (hl_x, hl_y), font(round(128 * s_avg), bold=True, locale=locale), text_color, round(14 * s_avg))
    d.text((hl_x + round(4 * sx), round(730 * sy)), subline, font=font(round(38 * s_avg), locale=locale), fill=muted)

    # Phone — scaled and centred on wider canvas
    phone_w = round(slide.phone_width * s_avg)
    phone = make_phone(RAW / slide.source, phone_w, slide.scrub_y)
    phone_x = round(slide.phone_x * sx)
    phone_y = round(slide.phone_y * sy)
    canvas.alpha_composite(shadow_layer(phone, (phone_x, phone_y), canvas.size))
    canvas.alpha_composite(phone, (phone_x, phone_y))

    # Footer
    footer_left = get_slide_text(slide_idx, "footer_left", locale, slide)
    footer_right = get_slide_text(slide_idx, "footer_right", locale, slide)
    footer_fill = (255, 255, 255, 190) if slide.dark_text else (8, 24, 38, 132)
    footer_color = (24, 48, 74, 230) if slide.dark_text else (255, 255, 255, 238)
    footer_y1 = round(2622 * sy)
    footer_y2 = round(2724 * sy)
    footer_x1 = round(86 * sx)
    footer_x2 = w - footer_x1
    d.rounded_rectangle((footer_x1, footer_y1, footer_x2, footer_y2), radius=round(50 * s_avg), fill=footer_fill)
    footer_font = font(round(34 * s_avg), bold=True, locale=locale)
    d.text((footer_x1 + round(46 * s_avg), footer_y1 + round(32 * sy * 0.5 + 8)), footer_left, font=footer_font, fill=footer_color)
    # Right-align footer_right
    works_box = d.textbbox((0, 0), footer_right, font=footer_font)
    works_w = works_box[2] - works_box[0]
    d.text((footer_x2 - works_w - round(46 * s_avg), footer_y1 + round(32 * sy * 0.5 + 8)), footer_right, font=footer_font, fill=footer_color)

    return canvas.convert("RGB")


def generate_locale(locale: str) -> tuple[int, int]:
    """Generate all iPhone and iPad screenshots for a single locale.

    Returns (iphone_count, ipad_count).
    """
    locale_suffix = f"-{locale}" if locale != "en" else ""
    iphone_count = 0
    ipad_count = 0

    # --- iPhone screenshots ---
    base_dir = OUT / f"iphone-6.9{locale_suffix}"
    base_dir.mkdir(parents=True, exist_ok=True)
    rendered: list[tuple[str, Image.Image]] = []
    for idx, slide in enumerate(SLIDES):
        img = render_slide(slide, locale=locale, slide_idx=idx)
        filename = f"{slide.slug}-1320x2868.png"
        img.save(base_dir / filename, optimize=True)
        rendered.append((slide.slug, img))

    for size_name, (w, h) in SIZES.items():
        if size_name == "iphone-6.9":
            continue
        size_dir = OUT / f"{size_name}{locale_suffix}"
        size_dir.mkdir(parents=True, exist_ok=True)
        for slug, img in rendered:
            img.resize((w, h), Image.Resampling.LANCZOS).save(size_dir / f"{slug}-{w}x{h}.png", optimize=True)
    iphone_count = len(rendered) * len(SIZES)

    # --- iPad screenshots ---
    ipad_base_dir = OUT / f"ipad-13{locale_suffix}"
    ipad_base_dir.mkdir(parents=True, exist_ok=True)
    ipad_rendered: list[tuple[str, Image.Image]] = []
    for idx, slide in enumerate(SLIDES):
        img = render_slide_ipad(slide, locale=locale, slide_idx=idx)
        filename = f"{slide.slug}-{IPAD_CANVAS_W}x{IPAD_CANVAS_H}.png"
        img.save(ipad_base_dir / filename, optimize=True)
        ipad_rendered.append((slide.slug, img))

    for size_name, (w, h) in IPAD_SIZES.items():
        if size_name == "ipad-13":
            continue
        size_dir = OUT / f"{size_name}{locale_suffix}"
        size_dir.mkdir(parents=True, exist_ok=True)
        for slug, img in ipad_rendered:
            img.resize((w, h), Image.Resampling.LANCZOS).save(size_dir / f"{slug}-{w}x{h}.png", optimize=True)
    ipad_count = len(ipad_rendered) * len(IPAD_SIZES)

    return iphone_count, ipad_count


def main() -> None:
    import sys

    # Determine which locales to generate
    if "--locale" in sys.argv:
        idx = sys.argv.index("--locale")
        locales = [sys.argv[idx + 1]] if idx + 1 < len(sys.argv) else list(LOCALE_TEXT.keys())
    elif "--all-locales" in sys.argv:
        locales = list(LOCALE_TEXT.keys())
    else:
        locales = ["en"]

    total_iphone = 0
    total_ipad = 0
    for locale in locales:
        iphone, ipad = generate_locale(locale)
        total_iphone += iphone
        total_ipad += ipad
        print(f"  [{locale}] {iphone} iPhone + {ipad} iPad files")

    print(f"\nTotal: {total_iphone + total_ipad} files across {len(locales)} locale(s)")


if __name__ == "__main__":
    main()
