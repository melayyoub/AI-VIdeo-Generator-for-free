# A) check for existing keys
ls -la ~/.ssh

# B) make one (ed25519) if needed
ssh-keygen -t ed25519 -C "youremail@example.com"
# press Enter to accept defaults (~/.ssh/id_ed25519)

# C) start agent & add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# D) add the public key to GitHub
cat ~/.ssh/id_ed25519.pub
# copy the output → GitHub > Settings > SSH and GPG keys > New SSH key

# E) test
ssh -T git@github.com
# should say: "Hi <username>! You've successfully authenticated..."
