package com.tarteeb.tarteeb

/**
 * Cheap on-device pre-filter. Only messages that could describe a financial
 * transaction leave the native layer; everything else (personal chats, OTP
 * codes, promotions without amounts) is dropped immediately and never stored.
 * Full parsing and classification happen in Dart (lib/sms/).
 */
object FinancialFilter {
    private val currencyTokens = listOf(
        "sar", "sr", "ر.س", "ريال", "usd", "$", "دولار", "eur", "€", "يورو", "gbp", "£",
        "aed", "درهم", "kwd", "bhd", "qar", "omr", "egp", "دينار", "جنيه"
    )

    private val amountKeywords = listOf(
        "amount", "amt", "purchase", "paid", "debited", "credited", "withdraw", "refund", "transfer",
        "deposit", "payment", "fee", "مبلغ", "شراء", "خصم", "سحب", "إيداع", "ايداع", "حوالة", "تحويل",
        "استرداد", "سداد", "رسوم", "دفع", "عملية"
    )

    private val otpKeywords = listOf(
        "otp", "one time password", "one-time password", "verification code", "activation code",
        "passcode", "رمز التحقق", "رمز التفعيل", "كلمة المرور المؤقتة", "رمز التأكيد", "كود التحقق",
        "رمز لمرة واحدة"
    )

    fun normalizeDigits(s: String): String {
        val sb = StringBuilder(s.length)
        for (ch in s) {
            when (ch) {
                in '٠'..'٩' -> sb.append('0' + (ch - '٠'))
                in '۰'..'۹' -> sb.append('0' + (ch - '۰'))
                else -> sb.append(ch)
            }
        }
        return sb.toString()
    }

    fun isCandidate(body: String?): Boolean {
        if (body.isNullOrBlank()) return false
        if (body.length > 1600) return false
        val text = normalizeDigits(body).lowercase()
        if (!text.any { it in '0'..'9' }) return false
        if (otpKeywords.any { text.contains(it) }) return false
        return currencyTokens.any { text.contains(it) } || amountKeywords.any { text.contains(it) }
    }
}
