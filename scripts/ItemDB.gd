class_name ItemDB
## Catálogo data-driven de itens (GODOT-EQUIPMENT-INVENTORY-FOUNDATION-1).
##
## Fundação de equipamentos/mochila. Cada item é um Dictionary com:
##   name, cat (weapon/offhand/chest/boots/head/accessory/consumable),
##   slot (vazio se não-equipável), weapon_kind (sword/bow/staff/spear),
##   two_handed (arma ocupa as 2 mãos → sem offhand), stackable,
##   stats opcionais: attack/defense/max_hp/speed/magic, heal (consumível),
##   desc (texto curto), color (ícone placeholder até haver arte).
## NÃO há classes/arquétipos completos aqui — só dados. Materiais de drop seguem em
## GameState.materials (string→qtd); ligá-los a itens é o LOOT-TO-INVENTORY-1.

const SLOT_WEAPON := "weapon"
const SLOT_OFFHAND := "offhand"
const SLOT_HEAD := "head"
const SLOT_CHEST := "chest"
const SLOT_LEGS := "legs"
const SLOT_BOOTS := "boots"
const SLOT_ACCESSORY := "accessory"
const SLOT_RING := "ring"
const SLOT_BRACELET := "bracelet"

const SLOT_ORDER := ["weapon", "offhand", "head", "chest", "legs", "boots", "accessory", "bracelet", "ring"]
const SLOT_LABEL := {
	"weapon": "Arma", "offhand": "Mão sec.", "head": "Cabeça",
	"chest": "Peito", "legs": "Calça", "boots": "Botas", "accessory": "Acessório", "bracelet": "Bracelete", "ring": "Anel",
}

const ITEMS := {
	"sword_simple":  {"name": "Espada do Errante",  "cat": "weapon",     "slot": "weapon",  "weapon_kind": "sword", "two_handed": false, "attack": 6, "price": 40, "rarity": "common", "desc": "Lâmina de ferro do recruta.", "color": "c9ccd6"},
	"shield_simple": {"name": "Escudo de Ronda",  "cat": "offhand",    "slot": "offhand", "defense": 4, "price": 35, "rarity": "common", "desc": "Madeira reforçada com aro de ferro.", "color": "8a6d3a"},
	"bow_simple":    {"name": "Arco de Cedro",    "cat": "weapon",     "slot": "weapon",  "weapon_kind": "bow",   "two_handed": true,  "attack": 7, "price": 50, "rarity": "common", "desc": "Arco de caçador. Ocupa as duas mãos.", "color": "9c7b46"},
	"staff_simple":  {"name": "Cajado de Brasa Fria",  "cat": "weapon",     "slot": "weapon",  "weapon_kind": "staff", "two_handed": true,  "attack": 3, "magic": 6, "price": 55, "rarity": "common", "desc": "Galho rúnico. Ocupa as duas mãos.", "color": "7e6bd0"},
	"spear_simple":  {"name": "Lança de Patrulha",   "cat": "weapon",     "slot": "weapon",  "weapon_kind": "spear", "two_handed": true,  "attack": 8, "price": 60, "rarity": "common", "desc": "Alcance e perfuração. Ocupa as duas mãos.", "color": "b8bcc6"},
	"book_simple":   {"name": "Livro de Presságios",  "cat": "weapon",     "slot": "weapon",  "weapon_kind": "book",  "two_handed": true,  "attack": 2, "magic": 4, "price": 48, "rarity": "common", "desc": "Tomo rúnico do Oráculo — páginas que cortam. Suporte arcano, mata devagar. Ocupa as duas mãos.", "color": "b78cff"},
	"axe_simple":    {"name": "Machado Simples",   "cat": "weapon",     "slot": "weapon",  "weapon_kind": "axe",    "two_handed": false, "attack": 12, "price": 55, "rarity": "common", "desc": "Machado de lenhador (Guerreiro). Golpe mais ofensivo que a espada, um pouco mais lento. Uma mão (aceita escudo).", "color": "b6783a"},
	"hammer_simple": {"name": "Martelo Simples",   "cat": "weapon",     "slot": "weapon",  "weapon_kind": "hammer", "two_handed": false, "attack": 16, "price": 62, "rarity": "common", "desc": "Martelo de guerra (Guerreiro). Impacto pesado, o mais lento. Controle/atordoamento virão depois. Uma mão (aceita escudo).", "color": "9aa0a8"},
	"armor_simple":  {"name": "Couraça de Couro Batido","cat": "chest",      "slot": "chest",   "defense": 5, "max_hp": 15, "price": 70, "rarity": "common", "desc": "Cota de couro batido.", "color": "6b6f78"},
	"boots_simple":  {"name": "Botas do Errante",   "cat": "boots",      "slot": "boots",   "defense": 1, "speed": 20, "price": 45, "rarity": "common", "desc": "Couro leve; passo mais rápido.", "color": "5a4a36"},
	"potion_minor":  {"name": "Poção Menor de Cura",     "cat": "consumable", "slot": "",        "stackable": true, "heal": 40, "price": 15, "rarity": "common", "desc": "Restaura 40 de HP.", "color": "d2455a"},
	"potion_mana":   {"name": "Poção de Mana",           "cat": "consumable", "slot": "",        "stackable": true, "mana": 35, "price": 25, "rarity": "common", "desc": "Restaura 35 de mana (cap no máximo). Preparo do Mago/Oráculo.", "color": "3f7fe0"},
	# Drop de ITEM (não material): a Adaga do Bandido — arma fraca, vendável.
	"dagger_rusty":  {"name": "Adaga do Caminho Velho","cat": "weapon",    "slot": "weapon",  "weapon_kind": "sword", "two_handed": false, "attack": 4, "price": 24, "rarity": "common", "desc": "Lâmina cega largada por um bandido.", "color": "9a9a86"},
	# Equipamentos REFORÇADOS — só pela FORJA (não estão no estoque da loja). Recompensa do loop de hunt. UNCOMMON.
	"sword_reinforced": {"name": "Espada Reforjada do Errante", "cat": "weapon", "slot": "weapon", "weapon_kind": "sword", "two_handed": false, "attack": 11, "price": 80, "rarity": "uncommon", "desc": "Lâmina temperada na forja de Dorn.", "color": "dfe3ee"},
	"armor_reinforced": {"name": "Couraça de Ferro Frio", "cat": "chest", "slot": "chest", "defense": 9, "max_hp": 30, "price": 110, "rarity": "uncommon", "desc": "Couro batido com placas de ferro.", "color": "808691"},
	"boots_reinforced": {"name": "Botas de Marcha Pesada", "cat": "boots", "slot": "boots", "defense": 2, "speed": 35, "price": 90, "rarity": "uncommon", "desc": "Solado ágil, costura resistente.", "color": "6e5a42"},
	"bow_reinforced":   {"name": "Arco de Cristal Vivo", "cat": "weapon", "slot": "weapon", "weapon_kind": "bow", "two_handed": true, "attack": 13, "price": 100, "rarity": "uncommon", "desc": "Arco encordoado com seda de aranha.", "color": "caa46a"},
	"staff_reinforced": {"name": "Cajado do Véu Azul", "cat": "weapon", "slot": "weapon", "weapon_kind": "staff", "two_handed": true, "attack": 5, "magic": 11, "price": 110, "rarity": "uncommon", "desc": "Galho coroado por um foco de cristal.", "color": "9a86e0"},
	"spear_reinforced": {"name": "Lança de Ponta Rúnica", "cat": "weapon", "slot": "weapon", "weapon_kind": "spear", "two_handed": true, "attack": 14, "price": 110, "rarity": "uncommon", "desc": "Ponta de presa de javali endurecida.", "color": "cdd2dc"},
	# A30 — PARIDADE DE LADDER: SUPPORT ganha o degrau MID que faltava (só tinha book_simple). Identidade support = magic (dano) + max_hp (solo-viável); attack é peso morto p/ dano de support (CombatMath.player_flat_bonus "support" = só magic). CODEX_WEAPON_ASSET_REQUIRED (usa fallback de raridade + ícone genérico, sprite final pendente).
	"book_reinforced":  {"name": "Tomo do Oráculo Selado", "cat": "weapon", "slot": "weapon", "weapon_kind": "book", "two_handed": true, "attack": 4, "magic": 11, "max_hp": 12, "price": 115, "rarity": "uncommon", "desc": "Páginas relidas até virarem escudo. Suporte arcano com fôlego p/ segurar sozinho. CODEX_WEAPON_ASSET_REQUIRED.", "color": "b78cff"},
	"shield_reinforced":{"name": "Escudo de Cristal Azul", "cat": "offhand", "slot": "offhand", "defense": 8, "price": 90, "rarity": "uncommon", "desc": "Tábuas reforçadas com um núcleo de cristal.", "color": "9a7d4a"},
	# --- Itens mínimos p/ consolidar os slots novos (GODOT-EQUIPMENT-SLOTS-AUDIT-1) ---
	"pants_simple":  {"name": "Calça do Errante",   "cat": "legs",      "slot": "legs",     "defense": 4, "max_hp": 10, "price": 50, "rarity": "common", "desc": "Calça de couro batido; protege as pernas na estrada.", "color": "6b5436"},
	"ring_simple":   {"name": "Anel de Seiva Verde", "cat": "accessory", "slot": "ring",     "max_hp": 12, "price": 45, "rarity": "common", "desc": "Pedra de seiva petrificada; pulsa com vida.", "color": "5fae74"},
	"bracelet_simple":{"name": "Bracelete de Couro", "cat": "accessory", "slot": "bracelet", "defense": 2, "speed": 8, "price": 40, "rarity": "common", "desc": "Bracelete trançado com fecho de bronze.", "color": "9c7b46"},
	# --- Cabeça + Acessório: ativam os slots head/accessory que estavam sem item (GODOT-EQUIPMENT-HEAD-ACCESSORY-1) ---
	"helmet_simple": {"name": "Elmo de Ronda",      "cat": "head",      "slot": "head",     "defense": 3, "max_hp": 8, "price": 48, "rarity": "common", "desc": "Capacete de couro com aro de ferro; protege a cabeça.", "color": "7d8089"},
	"amulet_simple": {"name": "Amuleto de Brasa Fria","cat": "accessory","slot": "accessory", "magic": 4, "max_hp": 6, "price": 55, "rarity": "common", "desc": "Pingente rúnico morno ao toque; aguça a magia.", "color": "8e7ad6"},
	# Reforçados de FORJA (uncommon; fora do estoque da loja) — completam a árvore de upgrade dos slots novos.
	"helmet_reinforced": {"name": "Elmo de Ferro Frio", "cat": "head", "slot": "head", "defense": 6, "max_hp": 20, "price": 100, "rarity": "uncommon", "desc": "Couro batido com placas de ferro sobre o crânio.", "color": "888e99"},
	"amulet_reinforced": {"name": "Amuleto do Véu Azul", "cat": "accessory", "slot": "accessory", "magic": 7, "max_hp": 16, "price": 110, "rarity": "uncommon", "desc": "Foco de cristal preso por fio de prata; pulsa com poder.", "color": "9a86e0"},
	"ring_reinforced": {"name": "Anel de Seiva Petrificada", "cat": "accessory", "slot": "ring", "max_hp": 26, "speed": 10, "price": 100, "rarity": "uncommon", "desc": "Núcleo de seiva endurecido na forja; vida densa.", "color": "6fbf86"},
	# ★ CROSS_SPINE_FORGE_F5 — a 1ª LIGA entre espinhas: ferro do Pântano (Limo de Ferro) temperado no cristal da
	# Caverna (Fragmento de Cristal). RARE = um degrau acima dos reforçados de espinha-única (sidegrade forte, NÃO
	# quebra a progressão). O +max_hp é o cristal "lembrando" vitalidade no ferro morto. Só pela forja (cross-spine).
	"sword_memoria": {"name": "Lâmina Temperada na Memória", "cat": "weapon", "slot": "weapon", "weapon_kind": "sword", "two_handed": false, "attack": 14, "max_hp": 10, "price": 140, "rarity": "rare", "desc": "Ferro do brejo remontado, temperado no cristal da Caverna. A lâmina guarda um fio que o ferro morto já esquecera — e um frio que não esfria. Liga duas terras numa só arma.", "color": "9ad6e0"},
	# ★ CROSS_SPINE_FORGE_F5 (expansão pós-validação) — a 2ª LIGA: elos de ferro do Pântano recozidos na luz fria do
	# cristal da Caverna (Pó Luminescente). RARE, 1 degrau acima da couraça reforçada. A 2ª liga = a regra do mundo
	# (não mais 1 experimento solto). Cross-spine: ferro (Pântano) + pó luminescente (Caverna).
	"armor_memoria": {"name": "Malha de Ferro-Memória", "cat": "chest", "slot": "chest", "defense": 11, "max_hp": 36, "price": 150, "rarity": "rare", "desc": "Elos de ferro do brejo recozidos na luz fria do cristal. Pesada — mas guarda o frio que apara o golpe antes de doer. A segunda liga das duas terras.", "color": "9ab6c8"},
	# ★ REGIONAL_GEAR_F5 — a 1ª peça HORIZONTAL: um SIDEGRADE (não um tier acima). MESMA arte/banda/atk da liga (14),
	# mas DISTRIBUIÇÃO oposta: a liga cunha +HP (robustez); esta cunha +VELOCIDADE (presteza) e NÃO dá HP. Identidade
	# da CATEDRAL (cristal vivo: leve, gélido, rápido). Compete com a liga, não a substitui. Poder total no mesmo patamar.
	"sword_crystal": {"name": "Gume de Cristal Frio", "cat": "weapon", "slot": "weapon", "weapon_kind": "sword", "two_handed": false, "attack": 14, "speed": 24, "price": 135, "rarity": "rare", "desc": "Lasca de cristal vivo da Catedral, leve e gélida — corta rápido e apressa o passo. Mas não carrega o peso (nem a vida) do ferro forjado: troca robustez por presteza. Escolha-a quando precisar DESVIAR mais do que AGUENTAR.", "color": "bfe6ee"},
	# --- SUPORTES DE REFINO (FATIA A7.1, PARTE G) — consumíveis STACKÁVEIS (NÃO ItemInstance). `refine_role`
	# marca a função; `acquisition_tags` prepara monetização FUTURA (§56) sem implementar loja. Não vendáveis
	# na loja da vila (price 0) — vêm de first-clear (§53/§54). Efeito lido pelo RefineMath/GameState, não aqui.
	"catalyst_refine":   {"name": "Catalisador de Refino", "cat": "consumable", "slot": "", "stackable": true, "refine_role": "catalyst", "catalyst_pp": 0.05, "price": 0, "rarity": "uncommon", "acquisition_tags": ["gameplay", "event", "future_store_allowed"], "desc": "Some +5 pontos percentuais na chance da PRÓXIMA tentativa de refino.", "color": "6fcf97"},
	"catalyst_superior": {"name": "Catalisador Superior", "cat": "consumable", "slot": "", "stackable": true, "refine_role": "catalyst", "catalyst_pp": 0.15, "price": 0, "rarity": "rare", "acquisition_tags": ["gameplay", "event", "future_store_allowed"], "desc": "Some +15 pontos percentuais na chance da PRÓXIMA tentativa de refino.", "color": "c9a0ff"},
	"seal_preservation": {"name": "Selo de Preservação", "cat": "consumable", "slot": "", "stackable": true, "refine_role": "preserve", "price": 0, "rarity": "rare", "acquisition_tags": ["gameplay", "event", "future_store_allowed"], "desc": "Se a tentativa falhar, impede a queda de nível do slot. Fragmentos ainda são gastos.", "color": "e8c267"},
	"seal_absolute":     {"name": "Selo Absoluto", "cat": "consumable", "slot": "", "stackable": true, "refine_role": "absolute", "price": 0, "rarity": "rare", "acquisition_tags": ["gameplay", "event", "future_store_controlled"], "desc": "Garante 100% de sucesso em UMA tentativa de refino. Ultra raro.", "color": "ffd27a"},
	# ═══ FATIA A7.3 — TIERS DE GEAR 4 (épico) e 5 (lendário) p/ fechar a curva 1-100 sem CP artificial (§11).
	# Bases REAIS (entram no ItemInstance/rolls/refino/joias normalmente). Drop por capítulo (ver ContentManifest).
	# Escalados por simulação: build maxada com Tier 5 alcança R>1.2 na fase 100 (P0 minmax). ART_REQUIRED (usam
	# cor/placeholder; sprites finais faltam). tier N = chapter de drop aproximado (t4=cap 5-7, t5=cap 8-10).
	# --- ARMAS (tier 4/5) por arquétipo ---
	"sword_abyss":   {"name": "Lâmina do Abismo", "cat": "weapon", "slot": "weapon", "weapon_kind": "sword", "two_handed": false, "attack": 22, "max_hp": 20, "price": 260, "rarity": "epic", "tier": 4, "desc": "Aço temperado no vazio. ART_REQUIRED.", "color": "b060e0"},
	"sword_eternal": {"name": "Gume Eterno", "cat": "weapon", "slot": "weapon", "weapon_kind": "sword", "two_handed": false, "attack": 33, "max_hp": 30, "price": 480, "rarity": "legendary", "tier": 5, "desc": "Fio que não cede ao tempo. ART_REQUIRED.", "color": "ffcf5a"},
	"staff_abyss":   {"name": "Cajado do Abismo", "cat": "weapon", "slot": "weapon", "weapon_kind": "staff", "two_handed": true, "attack": 8, "magic": 20, "price": 260, "rarity": "epic", "tier": 4, "desc": "Foco arcano do vazio. ART_REQUIRED.", "color": "a070e0"},
	"staff_eternal": {"name": "Cajado Eterno", "cat": "weapon", "slot": "weapon", "weapon_kind": "staff", "two_handed": true, "attack": 12, "magic": 31, "price": 480, "rarity": "legendary", "tier": 5, "desc": "Foco que perfura eras. ART_REQUIRED.", "color": "ffcf5a"},
	# A30 — PARIDADE tier5: RANGED e REACH tinham teto em _reinforced (sem eternal); SUPPORT nem isso. Identidade preservada:
	# ranged(arco)=attack alto + speed (consistência/cadência, sem sustain=glass); reach(lança)=maior attack cru, sem sustain;
	# support(livro)=magic (dano) + max_hp (solo-viável), NÃO ataque. Poder por STAT REAL (equip_sum → PowerBudget.cp), zero bônus fake. CODEX_WEAPON_ASSET_REQUIRED.
	"bow_eternal":   {"name": "Arco Eterno", "cat": "weapon", "slot": "weapon", "weapon_kind": "bow", "two_handed": true, "attack": 32, "speed": 24, "price": 480, "rarity": "legendary", "tier": 5, "desc": "Corda que não afrouxa; cada flecha chega igual à anterior. CODEX_WEAPON_ASSET_REQUIRED.", "color": "ffcf5a"},
	"spear_eternal": {"name": "Lança Eterna", "cat": "weapon", "slot": "weapon", "weapon_kind": "spear", "two_handed": true, "attack": 35, "price": 480, "rarity": "legendary", "tier": 5, "desc": "Alcance que fura eras — o toque mais longo, sem guarda que a segure. CODEX_WEAPON_ASSET_REQUIRED.", "color": "ffcf5a"},
	"book_eternal":  {"name": "Tomo Eterno", "cat": "weapon", "slot": "weapon", "weapon_kind": "book", "two_handed": true, "attack": 11, "magic": 31, "max_hp": 45, "price": 480, "rarity": "legendary", "tier": 5, "desc": "Palavras que não se apagam — cura e escudo que atravessam a solidão. CODEX_WEAPON_ASSET_REQUIRED.", "color": "ffcf5a"},
	# --- PEITO ---
	"chest_abyss":   {"name": "Couraça do Abismo", "cat": "chest", "slot": "chest", "defense": 18, "max_hp": 62, "price": 300, "rarity": "epic", "tier": 4, "desc": "Placas do vazio. ART_REQUIRED.", "color": "9a6fc0"},
	"chest_eternal": {"name": "Égide Eterna", "cat": "chest", "slot": "chest", "defense": 27, "max_hp": 96, "price": 540, "rarity": "legendary", "tier": 5, "desc": "Guarda que não quebra. ART_REQUIRED.", "color": "ffcf5a"},
	# --- CALÇA ---
	"legs_abyss":    {"name": "Grevas do Abismo", "cat": "legs", "slot": "legs", "defense": 12, "max_hp": 40, "price": 220, "rarity": "epic", "tier": 4, "desc": "ART_REQUIRED.", "color": "9a6fc0"},
	"legs_eternal":  {"name": "Grevas Eternas", "cat": "legs", "slot": "legs", "defense": 18, "max_hp": 60, "price": 400, "rarity": "legendary", "tier": 5, "desc": "ART_REQUIRED.", "color": "ffcf5a"},
	# --- BOTAS ---
	"boots_abyss":   {"name": "Passos do Abismo", "cat": "boots", "slot": "boots", "defense": 8, "max_hp": 26, "speed": 30, "price": 200, "rarity": "epic", "tier": 4, "desc": "ART_REQUIRED.", "color": "9a6fc0"},
	"boots_eternal": {"name": "Passos Eternos", "cat": "boots", "slot": "boots", "defense": 12, "max_hp": 40, "speed": 40, "price": 360, "rarity": "legendary", "tier": 5, "desc": "ART_REQUIRED.", "color": "ffcf5a"},
	# --- CABEÇA ---
	"head_abyss":    {"name": "Elmo do Abismo", "cat": "head", "slot": "head", "defense": 11, "max_hp": 38, "price": 200, "rarity": "epic", "tier": 4, "desc": "ART_REQUIRED.", "color": "9a6fc0"},
	"head_eternal":  {"name": "Elmo Eterno", "cat": "head", "slot": "head", "defense": 16, "max_hp": 56, "price": 360, "rarity": "legendary", "tier": 5, "desc": "ART_REQUIRED.", "color": "ffcf5a"},
	# --- OFFHAND (escudo) ---
	"shield_abyss":  {"name": "Broquel do Abismo", "cat": "offhand", "slot": "offhand", "defense": 16, "max_hp": 30, "price": 230, "rarity": "epic", "tier": 4, "desc": "ART_REQUIRED.", "color": "9a6fc0"},
	"shield_eternal":{"name": "Égide de Mão Eterna", "cat": "offhand", "slot": "offhand", "defense": 24, "max_hp": 46, "price": 420, "rarity": "legendary", "tier": 5, "desc": "ART_REQUIRED.", "color": "ffcf5a"},
	# --- ANEL / BRACELETE / ACESSÓRIO ---
	"ring_abyss":    {"name": "Anel do Abismo", "cat": "accessory", "slot": "ring", "max_hp": 44, "attack": 6, "price": 210, "rarity": "epic", "tier": 4, "desc": "ART_REQUIRED.", "color": "9a6fc0"},
	"ring_eternal":  {"name": "Anel Eterno", "cat": "accessory", "slot": "ring", "max_hp": 66, "attack": 10, "price": 380, "rarity": "legendary", "tier": 5, "desc": "ART_REQUIRED.", "color": "ffcf5a"},
	"bracelet_abyss":{"name": "Bracelete do Abismo", "cat": "accessory", "slot": "bracelet", "attack": 10, "defense": 8, "price": 210, "rarity": "epic", "tier": 4, "desc": "ART_REQUIRED.", "color": "9a6fc0"},
	"bracelet_eternal":{"name": "Bracelete Eterno", "cat": "accessory", "slot": "bracelet", "attack": 16, "defense": 12, "price": 380, "rarity": "legendary", "tier": 5, "desc": "ART_REQUIRED.", "color": "ffcf5a"},
	"amulet_abyss":  {"name": "Amuleto do Abismo", "cat": "accessory", "slot": "accessory", "max_hp": 40, "magic": 8, "price": 210, "rarity": "epic", "tier": 4, "desc": "ART_REQUIRED.", "color": "9a6fc0"},
	"amulet_eternal":{"name": "Amuleto Eterno", "cat": "accessory", "slot": "accessory", "max_hp": 60, "magic": 14, "price": 380, "rarity": "legendary", "tier": 5, "desc": "ART_REQUIRED.", "color": "ffcf5a"},
}

## --- ECONOMIA: LOJA & FORJA (GODOT-VILLAGE-SERVICES-SHOP-1) ---

## O que a Mercadora Sila vende (ids de ITEMS, na ordem da vitrine). Forjados ficam de fora.
const SHOP_STOCK := ["potion_minor", "potion_mana", "sword_simple", "axe_simple", "hammer_simple", "shield_simple", "helmet_simple", "armor_simple", "pants_simple", "boots_simple", "ring_simple", "bracelet_simple", "amulet_simple", "bow_simple", "staff_simple", "spear_simple", "book_simple"]

## Valor de revenda dos MATERIAIS de drop (string→gold). Default p/ materiais não listados.
## CAVERNA paga mais que PLANÍCIE (risco/recompensa). "Bolsa de Moedas" = praticamente gold.
const MATERIAL_VALUE := {
	# Planície (comuns, baratos)
	"Pelo de Lobo": 3, "Presa de Lobo": 5, "Carne Crua": 3,
	"Couro Áspero": 4, "Presa de Javali": 6, "Pano Rasgado": 4,
	"Bolsa de Moedas": 20,
	# Caverna (mais valiosos)
	"Asa de Morcego": 5, "Fragmento de Cristal": 8, "Pó Luminescente": 6,
	"Núcleo Trincado": 16, "Seda de Aranha": 6, "Glândula de Veneno": 9,
	"Gosma Pegajosa": 4, "Muco Verde": 3, "Essência de Sombra": 18,
	# Pântano de Ferro (GODOT-SWAMP-REGION-MVP-1) — tier pós-Caverna, valores moderados
	"Limo de Ferro": 7, "Raiz Pútrida": 6,
	# Ruínas da Estrada Velha (GODOT-EAST-REGION-1) — fragmento rúnico, tier médio
	"Pedra Rúnica": 8,
	# Bosque de Cinza (GODOT-NORTH-REGION-1) — cinza arcana, tier médio
	"Cinza Arcana": 8,
	# Coração das Raízes Negras (GODOT-DEEP-GROVE-1) — raiz negra (comum) + núcleo do mini-boss (raro)
	"Raiz Negra": 10, "Núcleo de Raiz Negra": 22,
	# Ninho da Raiz Ancestral (GODOT-ANCIENT-ROOT-NEST-1) — seiva cristalizada + fragmento do boss (fecha o arco)
	"Seiva Negra Cristalizada": 14, "Fragmento da Raiz Ancestral": 40,
	# Costa do Sal-Vento (GODOT-COAST-DESERT-ARC-START-1) — materiais costeiros (tier de entrada do arco)
	"Sal Cristalizado": 8, "Madeira de Naufrágio": 6, "Concha Polida": 5,
}
const DEFAULT_MATERIAL_VALUE := 2

## Raridade dos MATERIAIS (cosmético: cor/rótulo na UI). Derivada do valor/origem.
const MATERIAL_RARITY := {
	"Núcleo Trincado": "rare", "Essência de Sombra": "rare", "Bolsa de Moedas": "uncommon",
	"Glândula de Veneno": "uncommon", "Fragmento de Cristal": "uncommon", "Presa de Javali": "uncommon",
	"Presa de Lobo": "uncommon", "Seda de Aranha": "uncommon", "Pó Luminescente": "uncommon",
}

## Receitas da FORJA — a chave É o id do item produzido (ITEMS). Consome materiais + gold.
## ANTI-EXPLOIT: o custo (gold + valor dos materiais) é SEMPRE > valor de revenda do produzido
## → forjar é um SINK de gold (forja-se p/ USAR, nunca p/ revender com lucro).
const RECIPES := {
	"sword_reinforced": {"materials": {"Glândula de Veneno": 2, "Pano Rasgado": 1}, "gold": 50},
	# ★ CROSS_SPINE_FORGE_F5 — a LIGA: exige Fragmento de Cristal (SÓ a Caverna dá) + Limo de Ferro (SÓ o Pântano dá)
	# → forçar uma incursão em CADA espinha. Custo (45 mat + 90 ouro = 135) > revenda (~70) = sink preservado.
	"sword_memoria":    {"materials": {"Fragmento de Cristal": 3, "Limo de Ferro": 3}, "gold": 90},
	# ★ a 2ª LIGA: Limo de Ferro (SÓ Pântano) + Pó Luminescente (SÓ Caverna). Custo (39 mat + 100 ouro = 139) > revenda (~75) = sink.
	"armor_memoria":    {"materials": {"Limo de Ferro": 3, "Pó Luminescente": 3}, "gold": 100},
	# ★ REGIONAL_GEAR_F5 — peça REGIONAL (só Catedral/cristal, NÃO cross-spine): nasce de UMA terra. Custo (42 mat + 80 = 122) > revenda (67) = sink.
	"sword_crystal":    {"materials": {"Fragmento de Cristal": 3, "Pó Luminescente": 3}, "gold": 80},
	"spear_reinforced": {"materials": {"Presa de Javali": 2, "Couro Áspero": 2}, "gold": 60},
	"bow_reinforced":   {"materials": {"Couro Áspero": 3, "Seda de Aranha": 2}, "gold": 60},
	"staff_reinforced": {"materials": {"Fragmento de Cristal": 3, "Pó Luminescente": 2}, "gold": 65},
	# A30 — degrau MID do support (só existia book_simple). Materiais arcanos (Cristal+Luminescente da Caverna) = gate mid.
	"book_reinforced":  {"materials": {"Pó Luminescente": 3, "Fragmento de Cristal": 2}, "gold": 65},
	"armor_reinforced": {"materials": {"Pano Rasgado": 4, "Carne Crua": 2}, "gold": 60},
	"boots_reinforced": {"materials": {"Asa de Morcego": 3, "Muco Verde": 2}, "gold": 50},
	"shield_reinforced":{"materials": {"Couro Áspero": 2, "Núcleo Trincado": 1}, "gold": 55},
	"helmet_reinforced":{"materials": {"Couro Áspero": 3, "Fragmento de Cristal": 1}, "gold": 55},
	"amulet_reinforced":{"materials": {"Pó Luminescente": 2, "Essência de Sombra": 1}, "gold": 60},
	"ring_reinforced":  {"materials": {"Fragmento de Cristal": 2, "Seda de Aranha": 2}, "gold": 55},
	"potion_minor":     {"materials": {"Gosma Pegajosa": 2, "Muco Verde": 1}, "gold": 10},
}
const RECIPE_ORDER := ["sword_memoria", "sword_crystal", "armor_memoria", "sword_reinforced", "spear_reinforced", "bow_reinforced", "staff_reinforced", "book_reinforced", "armor_reinforced", "helmet_reinforced", "boots_reinforced", "shield_reinforced", "ring_reinforced", "amulet_reinforced", "potion_minor"]

## --- ÍCONES DE ITEM/MATERIAL (GODOT-HUD-BAG-EQUIP-ICONS-1 + EQUIPMENT-CURATED-PACK-INTEGRATION-1) ---
## Fonte oficial = pack curado do Codex (equipment_curated_pack_1) copiado p/ res://assets/ui/items/.
## Item: 1º ícone CURADO por-id (cada item tem o seu, ex.: sword_simple ≠ sword_reinforced); senão
## override → weapon_kind → cat (ícones genéricos antigos = fallback). Material: por NOME. "" = sem
## ícone (a UI cai no swatch de raridade).
const ICON_DIR := "res://assets/ui/items/"
## Ids com ícone curado dedicado (22 do pack). Lookup por id ASCII estável; o NOME exibido vem do label.
const CURATED_ICON_IDS := {
	"sword_simple": true, "sword_reinforced": true, "bow_simple": true, "bow_reinforced": true,
	"staff_simple": true, "staff_reinforced": true, "spear_simple": true, "spear_reinforced": true,
	"dagger_rusty": true, "shield_simple": true, "shield_reinforced": true, "armor_simple": true,
	"armor_reinforced": true, "boots_simple": true, "boots_reinforced": true, "helmet_simple": true,
	"helmet_reinforced": true, "ring_simple": true, "ring_reinforced": true, "amulet_simple": true,
	"amulet_reinforced": true, "potion_minor": true,
	"pants_simple": true, "bracelet_simple": true,   # ícones próprios (GODOT-EQUIPMENT-SLOTS-AUDIT-1)
	"book_simple": true, "axe_simple": true, "hammer_simple": true,   # ícones do Codex (GODOT-WEAPON-ITEM-ICONS-PLUG-1)
}
const ICON_BY_KIND := {"sword": "sword", "bow": "bow", "staff": "staff", "spear": "spear"}
const ICON_BY_CAT := {"offhand": "shield", "chest": "armor", "boots": "boots", "head": "helmet", "accessory": "amulet", "consumable": "potion"}
const ICON_OVERRIDE := {"dagger_rusty": "dagger"}   # fallback (curated já resolve dagger_rusty)
## Ícone-fantasma do slot vazio = versão "_simple" curada do tipo do slot.
const SLOT_ICON := {"weapon": "sword_simple", "offhand": "shield_simple", "head": "helmet_simple", "chest": "armor_simple", "legs": "pants_simple", "boots": "boots_simple", "accessory": "amulet_simple", "bracelet": "bracelet_simple", "ring": "ring_simple"}
const MATERIAL_ICON := {
	"Presa de Lobo": "fang", "Presa de Javali": "fang", "Pelo de Lobo": "fur",
	"Fragmento de Cristal": "crystal", "Pó Luminescente": "dust", "Núcleo Trincado": "core",
	"Seda de Aranha": "silk", "Gosma Pegajosa": "slime", "Essência de Sombra": "shadow",
	"Bolsa de Moedas": "pouch", "Asa de Morcego": "batwing",
	"Pedra Rúnica": "runestone",   # GODOT-OLD-ROAD-VISUAL-PASS-1
	# Pack de materiais faltantes (GODOT-MISSING-MATERIAL-ICONS-1, Codex missing_material_icons_pack_1)
	"Carne Crua": "raw_meat", "Cinza Arcana": "arcane_ash", "Concha Polida": "polished_shell",
	"Couro Áspero": "rough_leather", "Fragmento da Raiz Ancestral": "ancestral_root_fragment",
	"Glândula de Veneno": "venom_gland", "Limo de Ferro": "iron_slime",
	"Madeira de Naufrágio": "shipwreck_wood", "Muco Verde": "green_mucus",
	"Núcleo de Raiz Negra": "black_root_core", "Pano Rasgado": "torn_cloth",
	"Raiz Negra": "black_root", "Raiz Pútrida": "rotten_root",
	"Sal Cristalizado": "crystallized_salt", "Seiva Negra Cristalizada": "crystallized_black_sap",
}

## Nome do arquivo de ícone (sem dir/ext) de um item, "" se não houver.
static func icon_file(id: String) -> String:
	if CURATED_ICON_IDS.has(id):
		return id   # ★ ícone curado por-item (pack oficial do Codex)
	if ICON_OVERRIDE.has(id):
		return str(ICON_OVERRIDE[id])
	var wk := weapon_kind(id)
	if ICON_BY_KIND.has(wk):
		return str(ICON_BY_KIND[wk])
	var c := str(get_item(id).get("cat", ""))
	if ICON_BY_CAT.has(c):
		return str(ICON_BY_CAT[c])
	return ""

## Caminho res:// do ícone do item, "" se não houver (fallback na UI).
static func icon_path(id: String) -> String:
	var f := icon_file(id)
	return (ICON_DIR + f + ".png") if f != "" else ""

## Caminho res:// do ícone de um MATERIAL (por nome), "" se não mapeado (fallback).
static func material_icon_path(mat_name: String) -> String:
	var f := str(MATERIAL_ICON.get(mat_name, ""))
	return (ICON_DIR + f + ".png") if f != "" else ""

## Ícone "fantasma" do slot vazio (placeholder do que vai ali), "" se desconhecido.
static func slot_icon_path(slot: String) -> String:
	var f := str(SLOT_ICON.get(slot, ""))
	return (ICON_DIR + f + ".png") if f != "" else ""

static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func exists(id: String) -> bool:
	return ITEMS.has(id)

## FATIA A7 — todos os ids do catálogo (p/ o Códice). Ordem estável de iteração do Dictionary.
static func all_ids() -> Array:
	return ITEMS.keys()

## FATIA A7 — quantos itens EQUIPÁVEIS existem no catálogo (base dos marcos do Códice — §46).
static func equippable_count() -> int:
	var n := 0
	for id in ITEMS:
		if str(ITEMS[id].get("slot", "")) != "":
			n += 1
	return n

static func display_name(id: String) -> String:
	return str(get_item(id).get("name", id))

static func is_equippable(id: String) -> bool:
	return str(get_item(id).get("slot", "")) != ""

static func slot_of(id: String) -> String:
	return str(get_item(id).get("slot", ""))

static func is_stackable(id: String) -> bool:
	return bool(get_item(id).get("stackable", false))

static func is_two_handed(id: String) -> bool:
	return bool(get_item(id).get("two_handed", false))

## Tipo da arma (sword/bow/staff/spear) ou "" se não for arma.
static func weapon_kind(id: String) -> String:
	return str(get_item(id).get("weapon_kind", ""))

static func stat(id: String, key: String) -> int:
	return int(get_item(id).get(key, 0))

## Preço de COMPRA (gold). 0 = item sem preço (não comprável/vendível).
static func price(id: String) -> int:
	return int(get_item(id).get("price", 0))

## Valor de REVENDA na loja = metade do preço (arredondado).
static func sell_value(id: String) -> int:
	return int(round(price(id) * 0.5))

## Valor de revenda de um MATERIAL de drop (default p/ não listados).
static func material_value(mat_name: String) -> int:
	return int(MATERIAL_VALUE.get(mat_name, DEFAULT_MATERIAL_VALUE))

## --- RARIDADE LEVE (GODOT-LOOT-ECONOMY-PASS-2) — só cosmético: cor/rótulo na UI ---
const RARITY_COLOR := {"common": "d7dbe3", "uncommon": "6fcf97", "rare": "c9a0ff", "epic": "b060e0", "legendary": "ffcf5a"}

static func rarity(id: String) -> String:
	return str(get_item(id).get("rarity", "common"))

static func rarity_color(id: String) -> String:
	return str(RARITY_COLOR.get(rarity(id), "d7dbe3"))

static func rarity_label(r: String) -> String:
	match r:
		"uncommon": return "Incomum"
		"rare": return "Raro"
		"epic": return "Épico"
		"legendary": return "Lendário"
		_: return "Comum"

static func material_rarity(mat_name: String) -> String:
	return str(MATERIAL_RARITY.get(mat_name, "common"))

## id do item por NOME de exibição — p/ drops que são ITENS (não materiais). "" se não houver.
static func id_by_name(nm: String) -> String:
	for k in ITEMS:
		if str(ITEMS[k].get("name", "")) == nm:
			return str(k)
	return ""

## Receita da forja por id do item produzido ({} se não existir).
static func recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})

## Resumo curto de stats p/ a UI (ex.: "Atq +6"). "" se o item não tem stats.
static func stat_summary(id: String) -> String:
	var parts := PackedStringArray()
	for k in [["attack", "Atq"], ["defense", "Def"], ["max_hp", "HP"], ["speed", "Vel"], ["magic", "Mag"]]:
		var v := stat(id, str(k[0]))
		if v != 0:
			parts.append("%s +%d" % [k[1], v])
	var heal := stat(id, "heal")
	if heal > 0:
		parts.append("Cura %d" % heal)
	return "  ".join(parts)
