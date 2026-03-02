const CRITERIA = {
    len:      (s) => s.length >= 8,
    upper:    (s) => /[A-Z]/.test(s),
    number:   (s) => /[0-9]/.test(s),
    special:  (s) => /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?`~]/.test(s),
    notriple: (s) => !/(.)\1\1/.test(s),
};

function classificarSenha(senha) {
    if (!senha) return { level: 'Weak', criteria: {} };

    const c = {
        len:      CRITERIA.len(senha),
        upper:    CRITERIA.upper(senha),
        number:   CRITERIA.number(senha),
        special:  CRITERIA.special(senha),
        notriple: CRITERIA.notriple(senha),
    };

    // O score só usa os 3 critérios que combinamos
    const score = [c.upper, c.number, c.special].filter(Boolean).length;

    let level;
    if (score >= 2) {
        level = 'Strong';
    } else if (score === 1) {
        level = 'Medium';
    } else {
        level = 'Weak';
    }

    return { level, criteria: c };
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { classificarSenha };
}