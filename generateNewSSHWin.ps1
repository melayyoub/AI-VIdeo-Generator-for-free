# A) check for existing keys
Get-ChildItem $HOME\.ssh

# B) generate key
ssh-keygen -t ed25519 -C "youremail@example.com" -f $HOME\.ssh\id_ed25519

# C) ensure ssh-agent is running and auto-starts
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent

# D) add the key
ssh-add $HOME\.ssh\id_ed25519

# E) add the public key to GitHub
Get-Content $HOME\.ssh\id_ed25519.pub
# copy → GitHub > Settings > SSH and GPG keys > New SSH key

# F) test
ssh -T git@github.com
