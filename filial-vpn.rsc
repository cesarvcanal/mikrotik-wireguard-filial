# =====================================================================
# Filial conectada por WireGuard — RouterOS 7.6+
# Edite os parâmetros abaixo e cole o script inteiro no terminal.
# Pré-requisito: a interface wg-matriz já criada (passo 1 do README)
# e a chave pública desta filial cadastrada no gateway.
# =====================================================================

# ---------- parâmetros ----------
:local wgIface        "wg-matriz"
:local wgAddress      "10.90.0.10/24"
# IP desta filial dentro da VPN (um por loja)

:local gwPublicKey    "<CHAVE_PUBLICA_DO_GATEWAY>"
:local gwEndpoint     "vpn.suaempresa.com.br"
:local gwPort         51820

# redes que devem trafegar pelo túnel (VPN + redes internas da matriz)
:local redesInternas  "10.90.0.0/24,10.91.0.0/24"

# split-DNS: domínio interno e resolver que responde por ele
:local dominioInterno "interno"
:local dnsInterno     "10.90.0.1"

# ---------- endereço da VPN ----------
/ip address add address=$wgAddress interface=$wgIface comment="IP desta filial na VPN"

# ---------- peer: o gateway da matriz ----------
/interface wireguard peers add interface=$wgIface \
    public-key=$gwPublicKey \
    endpoint-address=$gwEndpoint endpoint-port=$gwPort \
    allowed-address=$redesInternas \
    persistent-keepalive=25s comment="gateway matriz"

# ---------- split-tunnel: so o interno roteia pelo tunel ----------
/ip route add dst-address=10.91.0.0/24 gateway=$wgIface comment="sistemas internos via VPN"

# ---------- split-DNS: *.interno resolve no resolver interno ----------
/ip dns set allow-remote-requests=yes
/ip dns static add regexp=(".*\\." . $dominioInterno . "\$") forward-to=$dnsInterno type=FWD \
    comment="dominio interno via VPN"

# ---------- NAT: LAN da loja sai pro tunel com o IP da filial ----------
/ip firewall nat add chain=srcnat out-interface=$wgIface action=masquerade \
    comment="LAN -> VPN (masquerade)"

# ---------- firewall: tunel so conversa com quem deve ----------
/ip firewall filter add chain=forward in-interface=$wgIface src-address=10.90.0.0/24 \
    action=accept comment="VPN -> LAN: permitido"
/ip firewall filter add chain=forward in-interface=$wgIface action=drop \
    comment="VPN -> LAN: resto bloqueado"

:put "Filial conectada. Confira o handshake em /interface wireguard peers print"
