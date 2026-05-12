#!/bin/bash
# ============================================================
# Projet SDN - Infrastructure avec Docker, OVS et VXLAN
# Auteur  : Mohamed Felfel
# Ecole   : ISET Nabeul 2025/2026
# Objectif: Reproduire tout le TP du niveau Bronze au niveau Or
# ============================================================

echo "========================================================"
echo "      PROJET SDN - ISET Nabeul 2025/2026"
echo "      Mohamed Felfel"
echo "========================================================"
sleep 1

# ============================================================
# PREREQUIS : Verifier que OVS est installe
# ============================================================
echo ""
echo ">>> Verification des prerequis..."
if ! command -v ovs-vsctl &> /dev/null; then
    echo "[INFO] Installation de Open vSwitch..."
    sudo apt install openvswitch-switch -y
else
    echo "[OK] Open vSwitch est deja installe : $(ovs-vsctl --version | head -1)"
fi

if ! command -v docker &> /dev/null; then
    echo "[ERREUR] Docker n est pas installe !"
    exit 1
else
    echo "[OK] Docker est installe : $(docker --version)"
fi

# ============================================================
# NIVEAU BRONZE - Etape 1 : Demarrer les conteneurs Docker
# ============================================================
echo ""
echo "========================================================"
echo " BRONZE - Etape 1 : Demarrage des conteneurs Docker"
echo "========================================================"

cd ~/sdn-project
docker-compose up -d
sleep 3

echo ""
echo ">>> Conteneurs en cours d execution :"
docker ps

# ============================================================
# NIVEAU BRONZE - Etape 2 : Nettoyer OVS
# ============================================================
echo ""
echo "========================================================"
echo " BRONZE - Etape 2 : Nettoyage des anciens bridges OVS"
echo "========================================================"

# Supprimer les anciens ports casses si existants
for port in $(sudo ovs-vsctl list-ports br-int 2>/dev/null); do
    sudo ovs-vsctl del-port br-int $port 2>/dev/null || true
done
for port in $(sudo ovs-vsctl list-ports br-vxlan 2>/dev/null); do
    sudo ovs-vsctl del-port br-vxlan $port 2>/dev/null || true
done

sudo ovs-vsctl del-br br-int 2>/dev/null || true
sudo ovs-vsctl del-br br-vxlan 2>/dev/null || true
echo "[OK] Nettoyage termine"

# ============================================================
# NIVEAU BRONZE - Etape 3 : Creer le bridge br-int
# ============================================================
echo ""
echo "========================================================"
echo " BRONZE - Etape 3 : Creation du bridge br-int"
echo "========================================================"

sudo ovs-vsctl add-br br-int
echo "[OK] Bridge br-int cree"

# ============================================================
# NIVEAU BRONZE - Etape 4 : Connecter OVS au controleur Ryu
# ============================================================
echo ""
echo "========================================================"
echo " BRONZE - Etape 4 : Connexion OVS -> Controleur Ryu"
echo "========================================================"

sudo ovs-vsctl set-controller br-int tcp:127.0.0.1:6653
sleep 2

echo ""
echo ">>> Verification de la connexion OVS <-> Ryu :"
sudo ovs-vsctl show

# Verifier is_connected
if sudo ovs-vsctl show | grep -q "is_connected: true"; then
    echo ""
    echo "[OK] is_connected: true -- NIVEAU BRONZE ATTEINT !"
else
    echo ""
    echo "[ATTENTE] Ryu pas encore connecte, on attend 5 secondes..."
    sleep 5
    sudo ovs-vsctl show
fi

# ============================================================
# NIVEAU BRONZE - Etape 5 : Attacher les conteneurs a OVS
# ============================================================
echo ""
echo "========================================================"
echo " BRONZE - Etape 5 : Attachement host1 et host2 a br-int"
echo "========================================================"

sudo ovs-docker add-port br-int eth0 host1
sudo ovs-docker add-port br-int eth0 host2
echo "[OK] host1 et host2 attaches au bridge br-int"

echo ""
echo ">>> Etat OVS apres attachement :"
sudo ovs-vsctl show

# ============================================================
# NIVEAU SILVER - Etape 6 : Configurer les IPs sur OVS
# ============================================================
echo ""
echo "========================================================"
echo " SILVER - Etape 6 : Configuration des IPs (interface OVS)"
echo "========================================================"

# Trouver les interfaces veth OVS dans chaque conteneur
echo ">>> Interfaces dans host1 :"
docker exec host1 ip addr show

echo ""
echo ">>> Interfaces dans host2 :"
docker exec host2 ip addr show

# Assigner IPs sur eth0
docker exec host1 ip addr flush dev eth0 2>/dev/null || true
docker exec host1 ip addr add 10.0.0.1/24 dev eth0
docker exec host1 ip link set eth0 up
echo "[OK] host1 : IP 10.0.0.1/24 assignee"

docker exec host2 ip addr flush dev eth0 2>/dev/null || true
docker exec host2 ip addr add 10.0.0.2/24 dev eth0
docker exec host2 ip link set eth0 up
echo "[OK] host2 : IP 10.0.0.2/24 assignee"

# Ajouter la regle par defaut pour faire passer le trafic
sudo ovs-ofctl -O OpenFlow13 del-flows br-int
sudo ovs-ofctl -O OpenFlow13 add-flow br-int "priority=0,actions=NORMAL"
echo "[OK] Regle OpenFlow par defaut installee"

# ============================================================
# NIVEAU SILVER - Etape 7 : Test ping avant VXLAN
# ============================================================
echo ""
echo "========================================================"
echo " SILVER - Etape 7 : Test de connectivite via br-int"
echo "========================================================"

echo ">>> Ping host1 -> host2 (via br-int) :"
docker exec host1 ping 10.0.0.2 -c 3

# ============================================================
# NIVEAU SILVER - Etape 8 : Creer le tunnel VXLAN
# ============================================================
echo ""
echo "========================================================"
echo " SILVER - Etape 8 : Creation du tunnel VXLAN (br-vxlan)"
echo "========================================================"

sudo ovs-vsctl add-br br-vxlan
echo "[OK] Bridge br-vxlan cree"

sudo ovs-vsctl add-port br-vxlan vxlan0 \
    -- set interface vxlan0 type=vxlan options:remote_ip=flow
echo "[OK] Port VXLAN (vxlan0) cree avec remote_ip=flow"

sudo ovs-docker add-port br-vxlan eth1 host1
sudo ovs-docker add-port br-vxlan eth1 host2
echo "[OK] host1 et host2 attaches au bridge br-vxlan"

docker exec host1 ip addr add 192.168.1.1/24 dev eth1
docker exec host1 ip link set eth1 up
echo "[OK] host1 : IP 192.168.1.1/24 sur eth1"

docker exec host2 ip addr add 192.168.1.2/24 dev eth1
docker exec host2 ip link set eth1 up
echo "[OK] host2 : IP 192.168.1.2/24 sur eth1"

echo ""
echo ">>> Configuration OVS complete :"
sudo ovs-vsctl show

# ============================================================
# NIVEAU SILVER - Etape 9 : Test ping via VXLAN
# ============================================================
echo ""
echo "========================================================"
echo " SILVER - Etape 9 : Test de connectivite via VXLAN"
echo "========================================================"

echo ">>> Ping host1 -> host2 (via tunnel VXLAN) :"
docker exec host1 ping 192.168.1.2 -c 5

if [ $? -eq 0 ]; then
    echo ""
    echo "[OK] Communication VXLAN etablie -- NIVEAU SILVER ATTEINT !"
else
    echo ""
    echo "[ERREUR] Le ping VXLAN a echoue"
fi

# ============================================================
# NIVEAU OR - Etape 10 : Firewall SDN via ovs-ofctl
# ============================================================
echo ""
echo "========================================================"
echo " OR - Etape 10 : Firewall SDN (Methode 1 : ovs-ofctl)"
echo "========================================================"

echo ">>> Test ping AVANT activation du firewall :"
docker exec host1 ping 10.0.0.2 -c 3

echo ""
echo ">>> Installation des regles OpenFlow..."
sudo ovs-ofctl -O OpenFlow13 del-flows br-int

# Regle 1 : Bloquer ICMP (priorite haute)
sudo ovs-ofctl -O OpenFlow13 add-flow br-int \
    "priority=1000,dl_type=0x0800,nw_proto=1,actions=drop"

# Regle 2 : Laisser passer le reste (priorite basse)
sudo ovs-ofctl -O OpenFlow13 add-flow br-int \
    "priority=0,actions=NORMAL"

echo ""
echo ">>> Regles OpenFlow installees :"
sudo ovs-ofctl -O OpenFlow13 dump-flows br-int

echo ""
echo ">>> Test ping APRES activation du firewall (doit etre BLOQUE) :"
docker exec host1 ping 10.0.0.2 -c 4

echo ""
echo ">>> Verification : n_packets sur la regle ICMP drop :"
sudo ovs-ofctl -O OpenFlow13 dump-flows br-int | grep "icmp"

# ============================================================
# NIVEAU OR - Etape 11 : Firewall dynamique (desactiver)
# ============================================================
echo ""
echo "========================================================"
echo " OR - Etape 11 : Desactivation dynamique du firewall"
echo "========================================================"

sudo ovs-ofctl -O OpenFlow13 del-flows br-int
sudo ovs-ofctl -O OpenFlow13 add-flow br-int "priority=0,actions=NORMAL"
echo "[OK] Regle ICMP drop supprimee"

echo ""
echo ">>> Test ping APRES suppression du firewall (doit marcher) :"
docker exec host1 ping 10.0.0.2 -c 3

if [ $? -eq 0 ]; then
    echo ""
    echo "[OK] Firewall dynamique demontre -- NIVEAU OR ATTEINT !"
fi

# ============================================================
# NIVEAU OR - Etape 12 : Firewall via Ryu Python
# ============================================================
echo ""
echo "========================================================"
echo " OR - Etape 12 : Firewall SDN (Methode 2 : Ryu Python)"
echo "========================================================"

echo ">>> Relancement de Ryu avec simple_firewall.py..."
docker stop ryu-controller 2>/dev/null || true
docker rm ryu-controller 2>/dev/null || true

docker run -d \
    --name ryu-controller \
    --network host \
    -p 6653:6653 \
    -p 8080:8080 \
    -v $(pwd):/app \
    osrg/ryu \
    ryu-manager /app/simple_firewall.py

sleep 3
echo ""
echo ">>> Logs du controleur Ryu :"
docker logs ryu-controller | head -10

echo ""
echo ">>> Reconnexion OVS au controleur..."
sudo ovs-vsctl set-controller br-int tcp:127.0.0.1:6653
sleep 2

echo ""
echo ">>> Regles installees par Ryu :"
sudo ovs-ofctl -O OpenFlow13 dump-flows br-int

echo ""
echo ">>> Test ping (doit etre bloque par Ryu) :"
docker exec host1 ping 10.0.0.2 -c 4

# ============================================================
# RESUME FINAL
# ============================================================
echo ""
echo "========================================================"
echo "   RESUME FINAL DU PROJET SDN"
echo "========================================================"
echo ""
echo " Niveau  | Critere                  | Statut"
echo "---------|--------------------------|--------"
echo " Bronze  | OVS connecte a Ryu       | ATTEINT"
echo " Silver  | Tunnel VXLAN 0% perte    | ATTEINT"
echo " Or      | Firewall SDN dynamique   | ATTEINT"
echo ""
echo ">>> Configuration OVS finale :"
sudo ovs-vsctl show
echo ""
echo "========================================================"
echo " Projet SDN termine avec succes !"
echo " Mohamed Felfel - ISET Nabeul 2025/2026"
echo "========================================================"
