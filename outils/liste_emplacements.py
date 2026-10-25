# Liste propre des emplacements (checks) a partir de emplacements.tsv (extraire_checks.py)
import csv, glob, os, json, collections

dossier = {}
for f in glob.glob('cartes/**/*.umap', recursive=True):
    chemin = f.replace(os.sep, '/')
    if '/Maps/' in chemin:
        dossier[os.path.basename(chemin)[:-5]] = chemin.split('/Maps/')[1].rsplit('/', 1)[0]

r = list(csv.DictReader(open('emplacements.tsv', encoding='utf-8'), delimiter='\t'))

# Objet par defaut des ramassables speciaux (valeur dans leur Blueprint, pas dans la carte)
defaut = {
    'BackstagePass_C': 'BackstagePass', 'BowlingTicket_C': 'BowlingTicket', 'MazercizeTicket_C': 'MazerciseTicket',
    'DancePassCollectible_C': 'DancePass', 'ComplimentaryPass_C': 'CompPass', 'PhotoPassCollectible_C': 'PhotoPass',
    'MrHippoMagnet_C': 'MrHippoMagnet', 'MontyMysteryMix_C': 'MontyMysteryMix', 'MazerciseControlKey_C': 'MazerciseControlKey',
    'CollectibleStaffbotHead_C': 'DamagedHead', 'FlashBeaconCollect_C': 'FlashBeacon',
    'ChicaGreenroomCollectible_C': 'PartyPassChicaRoom', 'LaserGunCollectible_Prize_C': 'Fazergun',
    'PRE_BadgeHolder_Daycare_C': 'SecurityBadgeDaycare', 'Pre_BadgeHolder_Backstage_C': 'SecurityBadgeBackstage',
    'PRE_BadgeHolder_PrizeCounter_C': 'SecurityBadgePrizeCounter', 'PRE_BadgeHolder_Warehouse_C': 'SecurityBadgeWarehouse',
    'PRE_BadgeHolder_WestArcade_C': 'SecurityBadgeWestArcade',
}
# Pas des emplacements : recharges de lampe, declencheurs, robots a billet, pistolet prete pour le mini-jeu
exclus = {
    'FlashlightCollectible_C', 'UpdateMissionOnCollect_C', 'PartyPassDoorManager_C', 'StaffBotPartyPass_C',
    'PartyPassTrigger_C', 'FreddyPositionAfterPhotoPass_C', 'CollectibleSpawnTrigger_C', 'FazPassUpgradeMachine_C',
    'LaserGunCollectible_Game_C',
}


def type_(c):
    if 'Present' in c:
        return 'cadeau'
    if 'Message' in c:
        return 'message'
    if 'Tape' in c:
        return 'cd'
    if 'BadgeHolder' in c:
        return 'badge'
    return 'special'


out = []
for x in r:
    c = x['classe']
    if c in exclus:
        continue
    out.append({'id': x['carte'] + ':' + x['acteur'], 'type': type_(c), 'zone': dossier.get(x['carte'], '?'),
                'carte': x['carte'], 'classe': c, 'objet': x['objet'] or defaut.get(c, '?'),
                'pos': [x['x'], x['y'], x['z']]})
json.dump(out, open('emplacements.json', 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
print(len(out), collections.Counter(o['type'] for o in out))
print(collections.Counter(o['zone'] for o in out).most_common(40))
print('objet inconnu :', [(o['id'], o['classe']) for o in out if o['objet'] in ('?', '')])
