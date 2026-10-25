-- Messages reecrits (references de la commu) : on modifie directement les lignes de MessageDataTable,
-- donc la Fazwatch, les notifications et la liste des messages affichent nos textes.
-- Seulement des messages d'ambiance : jamais ceux qui donnent un indice de jeu (labyrinthe, compacteur,
-- robot-pilote, arcades Princess Quest...). Cle = nom de ligne de la table (pas la cle de traduction).
-- Langue = celle du jeu.
local O = require("sb.outils")

local TABLE = "/Game/Data/MessageDataTable.MessageDataTable"

local TEXTES = {
    -- Pres du circuit de Roxy : brouillon d'une lettre qu'elle n'ose pas envoyer
    RoxyBoss1 = {
        titre = {fr = "POUR ZINOXE (NE PAS ENVOYER)", en = "FOR ZINOXE (DO NOT SEND)"},
        fr = [[Cher Zinoxe,

Je suis la meilleure. Je suis TOUJOURS la meilleure. Sauf quand tu passes devant ma loge : là, mes yeux améliorés n'arrivent plus à faire la mise au point.

J'ai gagné toutes mes courses ce mois-ci, mais aucun trophée ne brille autant que... (gribouillé)

Tu sais que je vois à travers les murs ? Je ne te regarde pas. Enfin, pas tout le temps. Tu es beaucoup trop mignon quand tu crois que personne ne te voit. (gribouillé aussi)

J'ai même fait écrire ton nom en néon au-dessus de la piste. Z-I-N-O-X-E. Je l'ai éteint. Puis rallumé. Puis éteint.

Un jour, je te le dirai en face. Quand je serai prête. Quand je serai parfaite.

... C'est le 47e brouillon. Ne le lis pas, Zinoxe. Remets-le où tu l'as trouvé.
- R.]],
        en = [[Dear Zinoxe,

I am the best. I am ALWAYS the best. Except when you walk past my green room: then my upgraded eyes just can't focus.

I won every race this month, but no trophy shines like... (scribbled out)

You know I can see through walls? I'm not watching you. Well, not all the time. You look way too cute when you think nobody's watching. (also scribbled out)

I even had your name put up in neon above the track. Z-I-N-O-X-E. I turned it off. Then on again. Then off.

One day I'll tell you to your face. When I'm ready. When I'm perfect.

... This is draft #47. Don't read it, Zinoxe. Put it back where you found it.
- R.]],
    },
    -- Dave Miller = William Afton
    Complaint2 = {
        fr = [[PLAINTE CLIENT - Vous devriez virer Dave. Il est nul. En plus, il sent le costume de lapin brûlé et n'arrête pas de murmurer « Je reviens toujours ». Faites en sorte que non.]],
        en = [[CUSTOMER COMPLAINT - You should fire Dave. He sucks. He also smells like a burnt rabbit costume and keeps whispering "I always come back." Please make sure he doesn't.]],
    },
    StaffParty1 = {
        fr = [[Tu vas à la fête du personnel ? Monty répète « Let's Groove » devant le miroir des toilettes depuis trois semaines. Je veux pas rater ça. Mais je veux pas non plus être dans la même pièce que ça.]],
        en = [[Are you going to the staff party? Monty has been practicing "Let's Groove" in the bathroom mirror for three weeks. I don't want to miss that. I also don't want to be in the same room as that.]],
    },
    StaffParty2 = {
        fr = [[RAPPEL À TOUS LES EMPLOYÉS - La réunion du personnel a lieu jeudi soir à 23 h 30. Ordre du jour : 1) Où est Foxy ? 2) Non, sérieusement, où est Foxy ? 3) Qui donne à Chica de la pizza sortie des poubelles ? Il y aura du gâteau ! (Ne pas donner le gâteau à Chica.)]],
        en = [[REMINDER TO ALL EMPLOYEES - The all staff meeting is this Thursday night at 11:30PM. Agenda: 1) Where is Foxy? 2) No, seriously, where is Foxy? 3) Who keeps feeding Chica pizza from the trash? There will be cake! (Do not give the cake to Chica.)]],
    },
    NightTerrors = {
        fr = [[PLAINTE CLIENT - L'animateur de votre garderie a demandé à mon fils « Sun ou Moon ? ». Il a répondu « Pokémon ». Depuis, il refuse de dormir dans le noir et crie « EXTINCTION DES FEUX ! » à sa petite sœur. Je veux un remboursement. Et une veilleuse.]],
        en = [[CUSTOMER COMPLAINT - Your daycare attendant asked my son "Sun or Moon?". He said "Pokemon". Now he refuses to sleep with the lights out and keeps yelling "LIGHTS OUT!" at his little sister. I want a refund. And a night light.]],
    },
    KitchenStaffNote = {
        fr = [[À L'ATTENTION DU PERSONNEL DE CUISINE - Chica a encore été surprise en train de manger dans les poubelles de la cuisine après la fermeture. Encore. Le service technique dit que « ce n'est pas un bug, c'est un mode de vie ». Verrouillez les poubelles. Cachez la pizza. Priez. - LA DIRECTION]],
        en = [[ATTENTION KITCHEN STAFF - Chica has been caught eating from the kitchen garbage after hours. Again. Parts and Service says this is "not a bug, it's a lifestyle." Lock the trash cans. Hide the pizza. Pray. - MANAGEMENT]],
    },
    Freddy1 = {
        fr = [[PLAINTE CLIENT - Nous avons payé la formule Glam Freddy Mega Deluxe. Freddy est tombé en panne sur scène, a murmuré « Gregory... je ne me sens pas très... superstar », puis il a marché dans un mur pendant vingt minutes. Ma fille pense maintenant que tous les anniversaires finissent comme ça.]],
        en = [[CUSTOMER COMPLAINT - We paid for the Glam Freddy Mega Deluxe Party Package. Freddy broke down on stage, whispered "Gregory... I am not feeling very... superstar", then walked into a wall for twenty minutes. My daughter now thinks every birthday ends like this.]],
    },
    -- Phone Guy (FNaF 1)
    Staff1 = {
        fr = [[AVIS AU PERSONNEL - Bonne nouvelle ! Grâce aux S.T.A.F.F., plus besoin d'employés la nuit. Euh, allô ? Allô, allô ? Si vous lisez ceci, vous avez été remplacé. De toute façon, ce n'était que cinq nuits par semaine. Fazbear Entertainment décline toute responsabilité en cas de... enfin, vous voyez.]],
        en = [[ATTENTION EMPLOYEES - Good news! Thanks to S.T.A.F.F., night employees are no longer needed. Uh, hello? Hello, hello? If you're reading this, you've been replaced. It was only five nights a week anyway. Fazbear Entertainment is not responsible for any... well, you know.]],
    },
    BonnieMissing2 = {
        fr = [[RAPPORT DE LA DIRECTION - Le bowling a besoin d'un nouveau thème. Les enfants demandent sans arrêt « Où est Bonnie ? » et maintenant aussi « Où est Foxy ? ». Réponse officielle approuvée : « Question suivante ! » Ne JAMAIS prononcer le mot « Foxy » près de Roxy.]],
        en = [[MANAGEMENT REPORT - The bowling alley needs a re-theme. Kids keep asking "Where's Bonnie?" and now also "Where's Foxy?". Officially approved response: "Next question!" NEVER say the word "Foxy" near Roxy.]],
    },
    -- Les Toys de FNaF 2 en ont marre de Yochix, qui tryhard leur jeu (texte d'origine : coup de gueule de Ray)
    RayMessage = {
        titre = {fr = "PLAINTE DES TOYS", en = "TOY COMPLAINT"},
        fr = [[PLAINTE OFFICIELLE - Ici Toy Freddy, Toy Bonnie, Toy Chica, Mangle et Balloon Boy. On en a MARRE de Yochix.

Ce tryhardeur passe ses nuits sur FNaF 2. Il connaît le timing du masque de Freddy par cœur, la boîte à musique de la Marionnette n'est JAMAIS vide, et il a fini le mode 10/20 tellement de fois qu'on ne compte plus. On n'arrive plus à l'attraper. Même pas une fois.

Et pour cause : il ne lâche plus le jeu. Il ne prend même plus de douche. On le sent arriver avant même qu'il allume sa lampe torche. Mangle s'est mis une pince à linge sur ses deux têtes. Balloon Boy refuse de dire « Hi! » tant qu'il ne s'est pas lavé.

Quelqu'un peut lui dire d'aller prendre l'air ? Ou au moins une douche ? S'il vous plaît.
- Les Toys (au placard depuis 1987)]],
        en = [[OFFICIAL COMPLAINT - This is Toy Freddy, Toy Bonnie, Toy Chica, Mangle and Balloon Boy. We are SICK of Yochix.

That tryhard spends every night on FNaF 2. He knows the Freddy mask timing by heart, the Puppet's music box is NEVER empty, and he has beaten 10/20 mode so many times we lost count. We can't catch him anymore. Not even once.

Then again, he never stops playing. He doesn't even shower anymore. We can smell him before he even turns on his flashlight. Mangle put a clothespin on both of her heads. Balloon Boy refuses to say "Hi!" until he takes a bath.

Can someone tell him to go touch grass? Or at least take a shower? Please.
- The Toys (stuck in storage since 1987)]],
    },
    -- Mr. Cupcake (le cupcake de Chica)
    Complaint1 = {
        fr = [[PLAINTE CLIENT - La pizza qu'on a commandée était bizarre. Les parts n'étaient pas de la même taille, et une part avait des yeux. C'était Mr. Cupcake. Il m'a fait un clin d'œil. Mon fils dit qu'il est « trop mignon ». Je ne remets plus jamais les pieds ici sans une GROSSE réduction. - Une mère en colère]],
        en = [[CUSTOMER COMPLAINT - The pizza we ordered was weird. The slices were all different sizes, and one slice had eyes. It was Mr. Cupcake. He winked at me. My son says he's "so cute". I am never coming back unless I get a MAJOR discount. - Angry Mom]],
    },
    -- la theorie "Bonnie Bowl" de la commu
    BonnieMissing1 = {
        fr = [[RAPPORT DE LA DIRECTION - Bonnie étant hors service, Monty devient le nouveau bassiste. Problème : il a déjà cassé quatre basses avec ses griffes cette semaine. Bonne nouvelle : en hommage à Bonnie, le bowling s'appellera désormais « Bonnie Bowl ». Et non, on ne répondra à AUCUNE question sur la matière des boules.]],
        en = [[MANAGEMENT REPORT - With Bonnie out of commission, Monty is the new bass player. Problem: he has already broken four basses with his claws this week. Good news: in Bonnie's honor, the bowling alley is now called "Bonnie Bowl". And no, we will NOT answer any questions about what the balls are made of.]],
    },
    -- Purple Guy
    LilMusicMan2 = {
        fr = [[RAPPORT DE SÉCURITÉ - Quelqu'un a forcé une vitrine de Rockstar Row et volé les prototypes des petits Music Man à remonter. Sur les images des caméras, on ne voit qu'un gars violet. Il sourit. Il fait coucou à la caméra. Puis il part en courant, les bras le long du corps. Probablement rien à voir. Je préviens la police ? - Vanessa]],
        en = [[SECURITY REPORT - Someone broke into a Rockstar Row display case and stole the wind up toy Music Man prototypes. The security footage only shows a purple guy. He's smiling. He waves at the camera. Then he runs off, arms stiff at his sides. Probably unrelated. Should I call the police? - Vanessa]],
    },
    -- "Gregory is none other than..."
    LilMusicMan1 = {
        fr = [[Merci d'avoir contacté Entrepreneurs du Bâtiment Petit Budget. Les « claquements » dans vos conduits viennent d'un petit garçon qui rampe à l'intérieur. Quand on lui a demandé qui il était, il a répondu « Je ne suis autre que... » et il est reparti avant de finir sa phrase. Nous vous avons facturé quand même.]],
        en = [[Thank you for contacting Low Budget Building Contractors. The "clanging" in your vents is a small child crawling around. When asked who he was, he said "I am none other than..." and crawled away before finishing. We charged you anyway.]],
    },
    -- Le lore est garde (appel a la police, doline, ascenseur, Vanessa...), avec une reference en plus
    ["911Call"] = {
        fr = [[RAPPORT DE SÉCURITÉ - Un policier est passé ce soir. Il répondait à un appel d'urgence passé depuis l'intérieur du Pizzaplex. Impossible : j'étais seule ici, et je n'ai appelé personne. D'après lui, l'appelant ne disait qu'une chose, en boucle : « C'EST MOI ». Je l'ai renvoyé. Encore une blague. - Vanessa]],
        en = [[SECURITY REPORT - A local police officer came by tonight, responding to an emergency call made from inside the Pizzaplex. Impossible: I was the only one here, and I didn't call anyone. He said the caller only kept repeating one thing: "IT'S ME". I sent him away. Just another prank call. - Vanessa]],
    },
    Complaint3 = {
        fr = [[RÉCLAMATION CLIENT - Pourquoi avoir rouvert ? Tout le monde se souvient de ce qui est arrivé à ces enfants. Et de la morsure de 87. Et de celle de 83. Arrêtez de mettre des dents à vos robots.]],
        en = [[CUSTOMER COMPLAINT - Why did you reopen? Everyone remembers what happened to those kids. And the Bite of '87. And the one in '83. Stop giving your robots teeth.]],
    },
    Sinkhole1 = {
        fr = [[POINT CHANTIER - Chaque jour, un nouveau problème. On coule une section de piste, et à peine sèche, elle se fissure. Je crains qu'on construise sur une doline. Le géomètre dit que le sol sent le brûlé, et qu'un lapin doré lui a fait coucou depuis une fissure. On lui a donné sa journée.]],
        en = [[CONSTRUCTION UPDATE - Every day there's a new problem. We pour a new section of track and as soon as it dries, it cracks. I'm worried we're building over a sinkhole. The surveyor says the ground smells burnt, and that a golden rabbit waved at him from one of the cracks. We gave him the day off.]],
    },
    Sinkhole2 = {
        fr = [[POINT CHANTIER - Les baisses de tension continuent. Quelque chose tire une quantité énorme de courant sur le chantier. On a suivi un câble haute tension qui disparaît droit dans les fondations. Il est étiqueté « Afton Robotics, LLC ». Sûrement un vieux sous-traitant. On va percer pour voir ce qu'il y a dessous.]],
        en = [[CONSTRUCTION UPDATE - The brownouts keep coming. Something is drawing a massive amount of power from the worksite. We traced a high voltage cable that disappears right into the foundation. It's labeled "Afton Robotics, LLC". Probably some old subcontractor. We're going to bore in and see what's under there.]],
    },
    Sinkhole3 = {
        fr = [[POINT CHANTIER - On a percé les fondations : il y a un vieux puits d'ascenseur. Quelqu'un était forcément au courant. En bas, ça sent la pizza d'il y a trente ans, et on entend comme une respiration. Les gars disent que c'est la ventilation. Il n'y a pas de ventilation en bas. On descend demain matin.]],
        en = [[CONSTRUCTION UPDATE - We broke through the foundation: there's an old elevator shaft down there. Someone must have known. It smells like thirty-year-old pizza, and you can hear something like breathing. The guys say it's the ventilation. There is no ventilation down there. We go down in the morning.]],
    },
    Vanessa1 = {
        fr = [[FICHE D'EMBAUCHE - Chef de la sécurité. Aucune qualification. Recommandation interne (nom masqué). Note : la candidate a demandé une « indemnité de costume de lapin ». Accordée. Sans poser de questions.]],
        en = [[NEW HIRE SUMMARY - Head Security Guard. No prior qualifications. Internal reference (name withheld). Note: the candidate requested a "bunny costume allowance". Approved. No questions asked.]],
    },
    Vanessa2 = {
        fr = [[NOTES D'ENTRETIEN - Comme demandé, mes notes sur l'entretien pour le poste de chef de la sécurité. Vanessa est motivée et vive, mais sans aucune expérience utile. Elle a surtout demandé si la garde de nuit dure bien de minuit à 6 h, et si « le gars du téléphone » laisse encore des messages. La recommandation vient d'en haut, je sais. Avis défavorable.]],
        en = [[INTERVIEW NOTES - As requested, my notes on today's Chief Security Officer interview. Vanessa seems eager and bright, but has no relevant experience. Mostly she asked whether the night shift really runs from midnight to 6 AM, and whether "the phone guy" still leaves messages. I know the recommendation came from the top. I do not recommend her.]],
    },
    MontyBoss4 = {
        fr = [[RAPPORT DE COMPORTEMENT - Monty a encore raté le spectacle de la grande scène. Trouvé au même endroit que d'habitude : les passerelles au-dessus du Monty Golf. Le mois dernier, quelqu'un a fait un trou en un, le seau de l'ouragan l'a fait tomber : deux jambes cassées. Il a dit au service des pièces : « C'est encore un coup de Freddy. » Freddy n'était même pas là.]],
        en = [[ERRANT BEHAVIOR REPORT - Monty skipped the main stage show again. Found him where we always do: the catwalks over Monty Golf. Last month someone hit a hole in one and the hurricane bucket knocked him down: both legs broken. He told Parts and Service "Freddy did this." Freddy wasn't even there.]],
    },
    ChicaVoiceBoxMsg = {
        fr = [[JOURNAL TECHNIQUE : CHICA - Ne la laissez pas chanter ! Ça perturbe la navigation des autres robots. Pendant un spectacle : plateaux renversés, chaos, clients blessés, 12 procès. Elle ne chantait que « LET'S EAT!!! ». L'ancien modèle, au moins, se contentait de vous fixer. Remplacement conseillé.]],
        en = [[MAINT LOG: CHICA - Don't let her sing! It messes with the other bots' navigation. During a live show: dropped trays, chaos, guest injuries, 12 lawsuits. She only sang "LET'S EAT!!!". At least the old model just stared at you. Replacement advised.]],
    },
    RoxyEyesMsg = {
        fr = [[JOURNAL TECHNIQUE : ROXY - Roxy voit les choses autrement. Cette amélioration devait l'aider à gagner les courses. Effet secondaire : elle fixe les autres robots à travers les murs et leur parle. Surtout pour leur dire qu'elle est la meilleure. Les murs sont d'accord.]],
        en = [[MAINT LOG: ROXY - Roxy sees things differently. This upgrade was meant to help her win races. Side effect: she stares at the other bots through walls and talks to them. Mostly to tell them she's the best. The walls agree.]],
    },
    MontyClawsMsg = {
        fr = [[JOURNAL TECHNIQUE : MONTY - Les griffes de Montgomery lui permettent de jouer de la basse. Après les spectacles, il s'en sert surtout pour tout casser. Les grillages coûtent une fortune. Il appelle ça « un solo de basse ». Personne n'a demandé.]],
        en = [[MAINT LOG: MONTY - Montgomery's claw upgrade lets him play bass. After shows, he mostly uses them to wreck things. The fence repairs are getting costly. He calls it "a bass solo". Nobody asked.]],
    },
    BonnieMissing3 = {
        fr = [[RAPPORT DE SÉCURITÉ - 0 h 24 : Bonnie quitte sa loge de Rockstar Row vers l'est. 2 h 40 : Bonnie entre dans l'arcade est. 4 h 12 : Bonnie entre au Monty Golf. 4 h 13 : la caméra du Monty Golf se coupe. 4 h 20 : Monty ressort avec une basse neuve. Sûrement rien à voir.]],
        en = [[SECURITY REPORT - 12:24AM - Bonnie leaves his green room in Rockstar Row heading East. 2:40AM - Bonnie enters the East Arcade. 4:12AM - Bonnie enters Monty Golf. 4:13AM - Monty Golf camera goes offline. 4:20AM - Monty walks out with a brand new bass. Probably unrelated.]],
    },
}

local function langue()
    local ok, l = pcall(function()
        return StaticFindObject("/Script/Engine.Default__KismetInternationalizationLibrary"):GetCurrentLanguage():ToString()
    end)
    return (ok and type(l) == "string" and l:sub(1, 2) == "fr") and "fr" or "en"
end

O.boucle(2000, function()
    if not O.calme() then return false end
    local dt = StaticFindObject(TABLE)
    if not (dt and dt:IsValid()) then return false end
    local l, n = langue(), 0
    for nom, m in pairs(TEXTES) do
        local ok, err = pcall(function()
            local ligne = dt:FindRow(nom)
            if not ligne then return end
            if m.titre then ligne.Title = FText(m.titre[l]) end
            ligne.Description = FText(m[l])
            dt:AddRow(nom, ligne)
            n = n + 1
        end)
        if not ok then O.log("message", nom, tostring(err)) end
    end
    local verif = dt:FindRow("RoxyBoss1")
    O.log("messages reecrits :", n, "(" .. l .. "), verif :", verif and verif.Title:ToString() or "?")
    return true
end)

return {}
