// ================================================================
//  regex.js — KRACKEN frontend logic
//
//  Responsabilidades:
//  1. Classificação de força de senha (Weak / Medium / Strong)
//  2. Toggle de visibilidade dos inputs
//  3. Chamada ao backend POST /crack
//  4. Renderização dos resultados
// ================================================================

const API_URL = 'http://localhost:8082/crack';

let gpuEnabled = false;

// ================================================================
//  1. PASSWORD STRENGTH
//
//  Critérios:
//  - Fraca   : < 7 chars, OU tem tripla repetição (aaa), OU tem espaço
//  - Média   : ≥ 7 chars, sem triplas, sem espaço, mas falta pelo menos
//              um dos critérios avançados (maiúscula, número, especial)
//  - Forte   : ≥ 9 chars, sem triplas, sem pares repetidos (xyxy),
//              sem espaço, tem maiúscula + número + especial
// ================================================================

const CRITERIA = {
    len:       (s) => s.length >= 8,
    upper:     (s) => /[A-Z]/.test(s),
    number:    (s) => /[0-9]/.test(s),
    special:   (s) => /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?`~]/.test(s),
    notriple:  (s) => !/(.)\1\1/.test(s),
};

function classificarSenha(senha) {
    if (!senha) return null;

    const temEspaco   = /\s/.test(senha);
    const temTripla   = /(.)\1\1/.test(senha);
    const temPar      = /(..).*\1/.test(senha);

    const c = {
        len:      CRITERIA.len(senha),
        upper:    CRITERIA.upper(senha),
        number:   CRITERIA.number(senha),
        special:  CRITERIA.special(senha),
        notriple: CRITERIA.notriple(senha),
    };

    // Fraca: espaço, ou tripla, ou menos de 7 chars
    if (temEspaco || temTripla || senha.length < 7) {
        return { level: 'Weak', criteria: c };
    }

    // Forte: ≥9 chars, sem par repetido, tem upper+number+special
    const advancedScore = [c.upper, c.number, c.special].filter(Boolean).length;
    if (senha.length >= 9 && !temPar && advancedScore === 3) {
        return { level: 'Strong', criteria: c };
    }

    // Médio: resto
    return { level: 'Medium', criteria: c };
}

function updateStrengthUI(senha) {
    const bar    = document.getElementById('strength-bar');
    const label  = document.getElementById('strength-label');
    const result = classificarSenha(senha);

    // Critérios visuais
    const ids = { len: 'c-len', upper: 'c-upper', number: 'c-number', special: 'c-special', notriple: 'c-notriple' };
    const texts = {
        len:      '8+ characters',
        upper:    'Uppercase',
        number:   'Number',
        special:  'Special char',
        notriple: 'No repetitions',
    };

    for (const [key, elId] of Object.entries(ids)) {
        const el = document.getElementById(elId);
        if (!result) {
            el.textContent = `✗ ${texts[key]}`;
            el.classList.remove('met');
        } else {
            const met = result.criteria[key];
            el.textContent = `${met ? '✓' : '✗'} ${texts[key]}`;
            el.classList.toggle('met', met);
        }
    }

    bar.className    = 'strength-bar-fill';
    label.className  = 'strength-value';

    if (!result || !senha) {
        bar.style.width = '0%';
        label.textContent = '—';
        return;
    }

    const map = {
        Weak:   { w: '33%',  cls: 'weak',   txt: 'WEAK' },
        Medium: { w: '66%',  cls: 'medium',  txt: 'MEDIUM' },
        Strong: { w: '100%', cls: 'strong',  txt: 'STRONG' },
    };

    const m = map[result.level];
    bar.style.width   = m.w;
    bar.classList.add(m.cls);
    label.classList.add(m.cls);
    label.textContent = m.txt;
}

document.getElementById('password').addEventListener('input', function () {
    updateStrengthUI(this.value);
});

// ================================================================
//  2. TOGGLE VISIBILIDADE
// ================================================================
function togglePassword(inputId, iconElement) {
    const input = document.getElementById(inputId);
    const svg   = iconElement.querySelector('svg');

    if (input.type === 'password') {
        input.type = 'text';
        svg.innerHTML = `
            <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
            <line x1="1" y1="1" x2="23" y2="23"></line>`;
    } else {
        input.type = 'password';
        svg.innerHTML = `
            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
            <circle cx="12" cy="12" r="3"></circle>`;
    }
}

// ================================================================
//  3. GPU TOGGLE
// ================================================================
function toggleGPU() {
    gpuEnabled = !gpuEnabled;
    document.getElementById('gpu-toggle-wrap').classList.toggle('active', gpuEnabled);
}

// ================================================================
//  4. CRACK — chamada ao backend
// ================================================================
async function runCrack() {
    const pwdInput  = document.getElementById('password');
    const confInput = document.getElementById('confirm-password');
    const password  = pwdInput.value.trim();
    const confirm   = confInput.value.trim();
    const errEl     = document.getElementById('error-msg');
    const btn       = document.getElementById('crack-btn');
    const btnText   = document.getElementById('btn-text');
    const spinner   = document.getElementById('btn-spinner');

    errEl.classList.add('hidden');
    errEl.textContent = '';

    if (!password) {
        showError('Password field is empty.');
        return;
    }
    if (password !== confirm) {
        showError('Passwords do not match.');
        return;
    }
    if (password.length > 8) {
        showError('Brute force limited to 8 chars. Dictionary will still run.');
    }

    const classResult = classificarSenha(password);
    const strength    = classResult ? classResult.level : 'Weak';

    setLoading(true);
    showIdle(false);

    const body = new URLSearchParams({
        password: password,
        strength: strength,
        gpu:      gpuEnabled ? 'true' : 'false',
    });

    try {
        const response = await fetch(API_URL, {
            method:  'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body:    body.toString(),
        });

        if (!response.ok) {
            const txt = await response.text();
            throw new Error(`Server error ${response.status}: ${txt}`);
        }

        const data = await response.json();
        renderResult(data, strength);

    } catch (err) {
        showIdle(true);
        showError(err.message);
    } finally {
        setLoading(false);
    }
}

// ================================================================
//  5. RENDER RESULTADO
// ================================================================
function renderResult(data, strength) {
    const resultData = document.getElementById('result-data');
    const resultIdle = document.getElementById('result-idle');

    resultIdle.classList.add('hidden');
    resultData.classList.remove('hidden');

    const leaked  = data.leaked === 'yes';
    const method  = data.method || 'not_found';
    const verdictEl = document.getElementById('r-verdict');

    verdictEl.className = 'result-val verdict';

    if (leaked) {
        verdictEl.textContent = 'LEAKED';
        verdictEl.classList.add('leaked');
    } else if (method === 'brute_force' || method === 'brute_force_gpu') {
        verdictEl.textContent = 'CRACKED';
        verdictEl.classList.add('cracked');
    } else {
        verdictEl.textContent = 'SURVIVED';
        verdictEl.classList.add('survived');
    }

    const methodMap = {
        dictionary:  'DICTIONARY',
        brute_force: 'BRUTE FORCE',
        not_found:   'NOT FOUND',
    };
    document.getElementById('r-method').textContent = methodMap[method] || method.toUpperCase();

    document.getElementById('r-strength').textContent = strength.toUpperCase();

    const ct = parseFloat(data.cracktime_s);
    document.getElementById('r-cracktime').textContent =
        ct < 0.001 ? `${(ct * 1e6).toFixed(2)} µs` :
        ct < 1     ? `${(ct * 1000).toFixed(2)} ms` :
                     `${ct.toFixed(3)} s`;

    const att = parseInt(data.attempts);
    document.getElementById('r-attempts').textContent =
        att > 1e6 ? `${(att / 1e6).toFixed(2)}M` :
        att > 1e3 ? `${(att / 1e3).toFixed(1)}k` :
                    att.toString();

    const dc = parseInt(data.dict_entries_checked);
    document.getElementById('r-dict').textContent =
        dc > 1e6 ? `${(dc / 1e6).toFixed(2)}M lines` :
        dc > 1e3 ? `${(dc / 1e3).toFixed(1)}k lines` :
                   `${dc} lines`;

    const lat = parseFloat(data.latency_ns);
    document.getElementById('r-latency').textContent =
        lat > 1000 ? `${(lat / 1000).toFixed(2)} µs` :
                     `${lat.toFixed(2)} ns`;

    document.getElementById('r-engine').textContent =
        (data.binary === 'gpu') ? 'CUDA GPU' : 'CPU THREADS';

    const ts = data.timestamp ? data.timestamp.replace('T', ' ').split('.')[0] : '—';
    document.getElementById('r-terminal').textContent =
        `[${ts}] target="${data.password}" strength=${strength}\n` +
        `[phase-1] dictionary  → ${data.dict_entries_checked} entries in ${parseFloat(data.dict_time_s).toFixed(4)}s\n` +
        `[phase-2] brute-force → ${data.attempts} attempts\n` +
        `[result]  ${method.toUpperCase()} via ${data.binary?.toUpperCase() || 'CPU'}`;
}

// ================================================================
//  HELPERS
// ================================================================
function setLoading(on) {
    const btn    = document.getElementById('crack-btn');
    const text   = document.getElementById('btn-text');
    const spin   = document.getElementById('btn-spinner');

    btn.disabled = on;
    text.textContent = on ? 'RUNNING...' : 'CRACK IT';
    spin.classList.toggle('hidden', !on);
}

function showIdle(on) {
    document.getElementById('result-idle').classList.toggle('hidden', !on);
    document.getElementById('result-data').classList.toggle('hidden',  on);
}

function showError(msg) {
    const el = document.getElementById('error-msg');
    el.textContent = msg;
    el.classList.remove('hidden');
}