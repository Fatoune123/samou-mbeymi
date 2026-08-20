"""Moteur Machine Learning de Samou Mbeymi.

Le modèle Random Forest estime le niveau de risque post-récolte.
Le dataset d'entraînement combine un socle synthétique et, lorsqu'ils existent,
des exemples issus des données réelles de l'application. Les données réelles
sont étiquetées à partir du taux de perte observé sur chaque récolte.
"""
import os, joblib, numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, confusion_matrix
from sklearn.preprocessing import LabelEncoder
from .dataset import generer_dataset, CULTURES, REGIONS

MODELE_DIR=os.path.join(os.path.dirname(__file__),'modeles'); MODELE_PATH=os.path.join(MODELE_DIR,'modele_risque.pkl')

def _encoders(): return LabelEncoder().fit(CULTURES), LabelEncoder().fit(REGIONS)

def _vectoriser(exemples, ce, re):
    return np.column_stack([ce.transform([e['culture'] for e in exemples]),re.transform([e['region'] for e in exemples]),[e['mois'] for e in exemples],[e['quantite_kg'] for e in exemples],[e['stockage_formel'] for e in exemples]])

def _reelles():
    try:
        from ..models import Recolte
        out=[]
        for r in Recolte.objects.select_related('agriculteur','culture').all():
            q=float(r.quantite_kg); perte=float(r.total_pertes_kg); taux=(perte/q*100) if q else 0
            risque='eleve' if taux>12 else ('moyen' if taux>5 else 'faible')
            lieu=(r.lieu_stockage or '').lower(); formel=int(any(k in lieu for k in ['silo','entrepôt','entrepot','magasin','frigo','chambre froide','hangar']))
            culture=r.culture.nom if r.culture.nom in CULTURES else CULTURES[0]
            out.append({'culture':culture,'region':r.agriculteur.region if r.agriculteur.region in REGIONS else REGIONS[0],'mois':r.date_recolte.month,'quantite_kg':q,'stockage_formel':formel,'risque':risque})
        return out
    except Exception:
        return []

def entrainer(n_exemples=3000, inclure_reel=True):
    os.makedirs(MODELE_DIR,exist_ok=True)
    synth=generer_dataset(n=n_exemples)
    reel=_reelles() if inclure_reel else []
    exemples=synth+reel
    ce,re=_encoders(); X=_vectoriser(exemples,ce,re); y=[e['risque'] for e in exemples]
    Xtr,Xte,ytr,yte=train_test_split(X,y,test_size=.2,random_state=42,stratify=y)
    modele=RandomForestClassifier(n_estimators=300,max_depth=10,min_samples_leaf=3,class_weight='balanced',random_state=42,n_jobs=-1)
    modele.fit(Xtr,ytr); pred=modele.predict(Xte)
    metrics={'accuracy':float(accuracy_score(yte,pred)),'precision':float(precision_score(yte,pred,average='weighted',zero_division=0)),'recall':float(recall_score(yte,pred,average='weighted',zero_division=0)),'f1':float(f1_score(yte,pred,average='weighted',zero_division=0))}
    importance=dict(zip(['culture','region','mois','quantite_kg','stockage_formel'],[round(float(x),4) for x in modele.feature_importances_]))
    joblib.dump({'modele':modele,'culture_encoder':ce,'region_encoder':re,'metrics':metrics,'precision_test':metrics['accuracy'],'importance':importance,'n_synthetiques':n_exemples,'n_reelles':len(reel)},MODELE_PATH)
    return {'metrics':metrics,'importance':importance,'n_synthetiques':n_exemples,'n_reelles':len(reel),'n_total':len(exemples)}

def _charger():
    if not os.path.exists(MODELE_PATH): entrainer()
    return joblib.load(MODELE_PATH)

def predire_risque(culture_nom, region, mois, quantite_kg, lieu_stockage=''):
    data=_charger(); m=data['modele']; ce=data['culture_encoder']; re=data['region_encoder']
    culture=culture_nom if culture_nom in ce.classes_ else ce.classes_[0]; reg=region if region in re.classes_ else re.classes_[0]
    formel=int(any(k in (lieu_stockage or '').lower() for k in ['silo','entrepôt','entrepot','magasin','frigo','chambre froide','hangar']))
    X=np.array([[ce.transform([culture])[0],re.transform([reg])[0],int(mois),float(quantite_kg),formel]])
    proba=m.predict_proba(X)[0]; classes=list(m.classes_); risque=classes[int(np.argmax(proba))]
    facteurs=[]
    if int(mois) in (6,7,8,9,10): facteurs.append("Saison des pluies : l'humidité peut accélérer la détérioration.")
    if not formel: facteurs.append("Le lieu indiqué ne ressemble pas à un stockage formel.")
    if float(quantite_kg)>1500: facteurs.append("Volume important : renforcez le contrôle et la ventilation.")
    if not facteurs: facteurs.append("Aucun facteur aggravant majeur détecté par les variables disponibles.")
    return {'risque':risque,'risque_affiche':{'faible':'Faible','moyen':'Moyen','eleve':'Élevé'}[risque],'probabilites':{c:round(float(p),3) for c,p in zip(classes,proba)},'facteurs':facteurs,'recommandation':('Renforcez immédiatement le stockage et le suivi.' if risque=='eleve' else 'Planifiez un contrôle préventif.' if risque=='moyen' else 'Continuez le suivi préventif.'),'modele':{'type':'Random Forest','donnees_reelles':data.get('n_reelles',0),'donnees_synthetiques':data.get('n_synthetiques',0)}}

def analyser_photo(image_path):
    from PIL import Image
    img=Image.open(image_path).convert('RGB'); img.thumbnail((300,300)); pixels=np.asarray(img).reshape(-1,3).astype(float); r,g,b=pixels[:,0],pixels[:,1],pixels[:,2]; lum=(r+g+b)/3
    ternis=(((r>g)&(g>b)&(lum<120))|(lum<60)); taux=float(ternis.sum())/len(pixels)
    if taux<.12: cat,msg='bon_etat','Aucun signe visuel majeur de détérioration détecté.'
    elif taux<.30: cat,msg='a_surveiller','Quelques zones ternies détectées : vérification recommandée.'
    else: cat,msg='deterioration_probable','Proportion importante de zones ternies : inspection recommandée.'
    return {'taux_zones_ternies':round(taux*100,1),'categorie':cat,'message':msg,'limite':'Analyse colorimétrique indicative, pas un diagnostic agronomique certifié.'}
