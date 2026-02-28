import bcrypt

def hash_pin(pin):
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(pin.encode(), salt)
    return hashed