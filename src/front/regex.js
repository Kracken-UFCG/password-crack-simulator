function classificarSenha(senha) {
    // 1. Regra FORTE
    // - Sem espaços
    // - Entre 9 e 20 chars
    // - Sem triplas (aaa)
    // - Sem pares repetidos (xy...xy)
    const regexForte = /^(?!.*(.)\1\1)(?!.*(..).*\2)[^\s]{8,20}$/;

    // 2. Regra MÉDIA
    // - Sem espaços
    // - Pelo menos 7 caracteres
    // - Sem triplas (aaa)
    // - (Neste nível aceitamos pares repetidos, ex: "banana" passaria se tiver 7 chars)
    const regexMedia = /^(?!.*(.)\1\1)[^\s]{7,}$/;

    if (regexForte.test(senha)) {
        return "Strong";
    } else if (regexMedia.test(senha)) {
        return "Medium";
    } else {
        return "Weak";
    }
}

function togglePassword(inputId, iconElement) {
    const input = document.getElementById(inputId);
    const svg = iconElement.querySelector('svg');
    
    if (input.type === "password") {
        input.type = "text";
        
        svg.innerHTML = `
            <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
            <line x1="1" y1="1" x2="23" y2="23"></line>
        `;
    } else {
        input.type = "password";
        
        svg.innerHTML = `
            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
            <circle cx="12" cy="12" r="3"></circle>
        `;
    }
}