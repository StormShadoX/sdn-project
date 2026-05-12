# Projet SDN — Infrastructure avec Docker, OVS et VXLAN

## Description
Infrastructure de Réseaux Définis par Logiciel (SDN) réalisée dans le cadre d'un projet pédagogique de 2ème année.

## Technologies utilisées
- **Ubuntu 22.04** (VirtualBox)
- **Docker / docker-compose**
- **Open vSwitch 2.17.9**
- **Ryu Controller** (osrg/ryu)
- **OpenFlow 1.3**
- **VXLAN**
- **Wireshark / tshark**

## Architecture

## Niveaux atteints
| Niveau | Critère | Résultat |
|--------|---------|----------|
| 🥉 Bronze | Connectivité OVS ↔ Ryu | ✅ Atteint |
| 🥈 Silver | Tunnel VXLAN (0% perte) | ✅ Atteint |
| 🥇 Or | Firewall SDN dynamique | ✅ Atteint |

## Lancement rapide
```bash
# 1. Démarrer les conteneurs
docker-compose up -d

# 2. Initialiser OVS
bash scripts/init-sdn.sh

# 3. Vérifier
sudo ovs-vsctl show
```

## Fichiers
- `docker-compose.yml` — Orchestration des services
- `simple_firewall.py` — Firewall SDNRyu Python
- `scripts/init-sdn.sh` — Script d'initialisation OVS

## Auteur
Mohamed Felfel — ISET Nabeul 2025/2026
