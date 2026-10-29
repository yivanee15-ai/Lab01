// Generate random patterns + brute-force optimal cycle.  usage: gen N seed mode(0=any,1=chain-structure only)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int op[8],rs[8],rt[8],rd[8],lat[8],pred[8];
int wv(int i){return op[i]<=4;}
int rsv(int i){return op[i]<=3||op[i]==6;}
int rdv(int i){return op[i]==5;}
int dep(int i,int j){ // i<j
  int ri[3],nri=0,rj[3],nrj=0;
  if(rsv(i)){ri[nri++]=rs[i];ri[nri++]=rt[i];}
  if(rdv(i))ri[nri++]=rd[i];
  if(rsv(j)){rj[nrj++]=rs[j];rj[nrj++]=rt[j];}
  if(rdv(j))rj[nrj++]=rd[j];
  if(wv(i))for(int a=0;a<nrj;a++)if(rj[a]==rd[i])return 1;
  if(wv(j))for(int a=0;a<nri;a++)if(ri[a]==rd[j])return 1;
  if(wv(i)&&wv(j)&&rd[i]==rd[j])return 1;
  return 0;}
int best;
int ord[8],used[8];
void rec(int k,int prevstart,int *fin,int mx){
  if(mx>=best)return;
  if(k==8){best=mx;return;}
  for(int c=0;c<8;c++)if(!used[c]){
    int ok=1,r=0;
    for(int i=0;i<8;i++)if(pred[c]>>i&1){if(!used[i]){ok=0;break;}if(fin[i]>r)r=fin[i];}
    if(!ok)continue;
    int s=prevstart+1;if(k==0)s=0;if(r>s)s=r;
    int f=s+lat[c];used[c]=1;int old=fin[c];fin[c]=f;
    rec(k+1,s,fin,f>mx?f:mx);
    used[c]=0;fin[c]=old;}
}
// structure check: components of dependency graph must be cliques; <=2 nontrivial comps and if 2 they cover all 8
int structure_ok(){
  int comp[8];for(int i=0;i<8;i++)comp[i]=i;
  for(int ch=1;ch;){ch=0;for(int j=0;j<8;j++)for(int i=0;i<j;i++)if(pred[j]>>i&1&&comp[i]!=comp[j]){int a=comp[i]<comp[j]?comp[i]:comp[j];comp[i]=comp[j]=a;ch=1;}}
  // propagate fully
  for(int ch=1;ch;){ch=0;for(int j=0;j<8;j++)for(int i=0;i<j;i++)if(pred[j]>>i&1){if(comp[i]!=comp[j]){int a=comp[i]<comp[j]?comp[i]:comp[j];comp[i]=comp[j]=a;ch=1;}}}
  for(int i=0;i<8;i++)for(int j=i+1;j<8;j++)if(comp[i]==comp[j]&&!(pred[j]>>i&1))return 0;
  int cnt[8]={0},nt=0,in=0;for(int i=0;i<8;i++)cnt[comp[i]]++;
  for(int i=0;i<8;i++)if(cnt[i]>1){nt++;in+=cnt[i];}
  if(nt>2)return 0; if(nt==2&&in!=8)return 0; return 1;}
int main(int argc,char**argv){
  int N=atoi(argv[1]);srand(atoi(argv[2]));int mode=atoi(argv[3]);
  int lo[8]={1,1,20,30,6,6,2,1},hi[8]={5,5,40,50,10,10,4,1};
  FILE*fi=fopen("input.txt","w"),*fo=fopen("output.txt","w");
  fprintf(fi,"%d\n",N);
  for(int n=0;n<N;){
    int regs=2+rand()%7; // fewer regs -> more deps
    if(mode==1) regs=8; if(mode==2) regs=3+rand()%6;
    for(int i=0;i<8;i++){op[i]=rand()%8;rs[i]=rand()%regs;rt[i]=rand()%regs;rd[i]=rand()%8;
      if(mode==1){ if(rand()%2)op[i]=5+rand()%3; } if(mode==2&&rand()%3==0)op[i]=5+rand()%3;}
    for(int j=0;j<8;j++){pred[j]=0;for(int i=0;i<j;i++)if(dep(i,j))pred[j]|=1<<i;}
    if(mode>=1&&!structure_ok())continue;
    for(int o=0;o<8;o++)lat[o]=lo[o]+rand()%(hi[o]-lo[o]+1);
    int L[8];for(int i=0;i<8;i++)L[i]=lat[op[i]];
    int la[8];memcpy(la,lat,sizeof la);memcpy(lat,L,sizeof L); // lat per instr for brute
    best=1<<30;memset(used,0,sizeof used);int fin[8]={0};rec(0,0,fin,0);
    memcpy(lat,la,sizeof la);
    for(int i=0;i<8;i++)fprintf(fi,"%03x ",op[i]<<9|rs[i]<<6|rt[i]<<3|rd[i]);
    fprintf(fi,"\n");for(int o=0;o<8;o++)fprintf(fi,"%d ",lat[o]);fprintf(fi,"\n");
    fprintf(fo,"%d\n",best);n++;}
  return 0;}
