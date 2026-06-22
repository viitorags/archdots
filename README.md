# archdots 🏔️

Este repositório contém meus arquivos de configuração (dotfiles) para o **Arch Linux**, migrados e adaptados de uma configuração anterior baseada em **NixOS**.

Ele utiliza gerenciadores de janelas modernos baseados em Wayland (**Hyprland** e **Niri**) e ferramentas otimizadas para CLI e desenvolvimento.

---

## 🛠️ O que está incluído?

### Ambientes Gráficos (Compositores Wayland)
* **Hyprland**: Configuração moderna em Lua (`config/hypr/hyprland.lua`).
* **Niri**: Compositor em grid e scroll infinito (`config/niri/config.kdl`).

### Ferramentas de Terminal & Apps
* **Terminais**: Kitty.
* **Shell**: Zsh ([.zshrc](file:///home/vitor/archdots/.zshrc)) com histórico robusto, aliases otimizados para Arch/Git e suporte completo a plugins locais.
* **Gerenciador de Arquivos**: Yazi.
* **Visualizador de PDFs**: Sioyek.
* **Música na CLI**: Cava.

---

## 🚀 Instalação e Sincronização

> [!WARNING]
> **Não execute o script principal com `sudo` ou como `root`**. O instalador solicitará permissões administrativas (`sudo`) apenas quando necessário e rodará a compilação do AUR de forma segura com o seu usuário comum.

Para instalar tudo de forma interativa, execute o instalador principal na raiz do repositório:

```bash
cd ~/archdots
chmod +x scripts/*.sh
./scripts/install.sh
```

### ⚡ Executando Etapas Individuais (Flags)
Você pode utilizar flags para executar apenas partes específicas do processo de sincronização (ideal para automações ou atualizações rápidas, sem prompts de confirmação):

* **Instalar pacotes oficiais (Pacman)**:
  ```bash
  ./scripts/install.sh --pacman   # ou -p
  ```
* **Instalar pacotes do AUR (Paru)**:
  ```bash
  ./scripts/install.sh --aur      # ou -a
  ```
* **Instalar ferramentas customizadas (Rustup, npm, composer, flatpaks)**:
  ```bash
  ./scripts/install.sh --custom   # ou -c
  ```

---

## ⚙️ O que os Scripts fazem automaticamente?

1. **[01-pacman.sh](file:///home/vitor/archdots/scripts/01-pacman.sh)**:
   * **Downloads Paralelos**: Ativa automaticamente `ParallelDownloads` no seu `/etc/pacman.conf` para acelerar os downloads.
   * **Pacotes do Sistema**: Instala as dependências oficiais, incluindo os plugins `zsh-autosuggestions` e `zsh-syntax-highlighting`.
2. **[02-paru.sh](file:///home/vitor/archdots/scripts/02-paru.sh)**:
   * **Bootstrapping do Paru**: Instala o `paru-bin` do AUR caso ele não esteja presente.
   * **Pacotes AUR**: Sincroniza e atualiza todos os pacotes adicionais do AUR (Brave, VS Code, temas, etc.).
3. **[03-custom.sh](file:///home/vitor/archdots/scripts/03-custom.sh)**:
   * **Instalação Inteligente**: Instala `opencode`, `@claudecode/cli` (npm), pacotes globais do Composer (`laravel/installer`, `laravel/pint`) e Flatpaks de forma **idempotente** (não faz download se já estiverem instalados).
   * **Evita Sudo no NPM**: Detecta se o prefixo global do NPM é gravável pelo usuário comum antes de tentar usar `sudo`.
   * **Serviços de Sistema**: Ativa e inicia serviços como `docker`, `sddm`, `avahi-daemon` e `upower`.
   * **Inicialização do Rustup**: Configura a toolchain `stable` padrão do Rustup automaticamente.
   * **Oh My Zsh & Shell**: Instala o Oh My Zsh em modo silencioso (`--unattended`) para não sobrescrever o seu `.zshrc` nem iniciar uma nova sessão prematuramente, e altera o shell padrão para Zsh sem interromper o andamento do script.

---

## 📂 Aplicando as Configurações

Para aplicar as configurações no seu usuário, crie links simbólicos (symlinks) apontando deste repositório para o seu diretório local.

```bash
# Vincular a configuração do Zsh
ln -sf ~/archdots/.zshrc ~/.zshrc

# Vincular os diretórios de configuração
ln -sf ~/archdots/config/yazi ~/.config/yazi
ln -sf ~/archdots/config/niri ~/.config/niri
ln -sf ~/archdots/config/hypr ~/.config/hypr
```

---

## 💻 Pós-instalação e Ajustes

1. **Zsh como shell padrão**:
   ```bash
   chsh -s $(which zsh)
   ```
2. **Uso de Aliases Úteis**:
   * O [.zshrc](file:///home/vitor/archdots/.zshrc) já vem configurado com atalhos como `upd` (para rodar `paru -Syu`) e `conf` (para entrar na pasta de dotfiles).
