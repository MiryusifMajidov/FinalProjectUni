/// Loose but sane e-mail check: something@something.tld, no spaces.
///
/// The registration screen used `^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$`, which
/// allows exactly one dot after the @ — so it rejected perfectly valid
/// addresses on sub-domains such as `name@student.bhos.edu.az` or
/// `name@mail.example.co.uk`. Firebase Auth does the authoritative check.
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@.]{2,}$');

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());
