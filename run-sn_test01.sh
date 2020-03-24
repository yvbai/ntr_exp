#!/bin/bash

## Training on Sprekend Nederland data; start from scratch

. ./cmd.sh 
[ -f path.sh ] && . ./path.sh
set -e

#YU# names of train-sn2/ and test-sn2/ folders
train=train-sn2
dev=test-sn2
nrcdev=test-nrc-dev

## acoustic training experiment number.  
## nr=7

#YU# paths to data/ including lmdir/ lang/ local/ local/dict
lm="data/lmdir"
lang="data/lang"
local="data/local"
dict="data/local/dict"

#YU# path to mfcc/
mfccdir=mfcc

feats_nj=60

#YU# paths to exp/ including mono/ tri1/ tri2b/ tri3b/ tri4b/ ubm/ sgmm/
mono=exp/mono # -$nr
tri1=exp/tri1 # -$nr
tri2b=exp/tri2b # -$nr
tri3b=exp/tri3b # -$nr
tri4b=exp/tri4b # -$nr
ubm=exp/ubm #-$nr
sgmm=exp/sgmm #-$nr

lang=data/lang

if false; then

#YU# new comment
# local/sn-make-data.py
#YU#

#YU# check train/ and test/ folders
utils/validate_data_dir.sh --no-feats data/train-sn2/
utils/validate_data_dir.sh --no-feats data/test-sn2/

#YU# generate mfcc/ exp/make_mfcc/train/ exp/make_mfcc/test/
## make mfcc's: real    8m11.878s
for x in $train $dev; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $feats_nj data/$x exp/make_mfcc/$x $mfccdir
    ## these lines are no longer necessary because we've removed small wavs in sn-make-data.py
    #utils/fix_data_dir.sh data/$x
    #feat-to-dim scp:data/$x/feats.scp ark,t:- | awk '$2 == 0' > data/$x/0-feats
    #filter_scp.pl --exclude data/$x/0-feats data/$x/feats.scp > feats.scp
    #mv feats.scp data/$x/
    steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
done

#YU# new comment
# ## make pronunciation dictionary (specific for training)
# ../bin/find-oov.py --dict fame/dict/orig/celex-novo54.dict --text data/$train/text > data/$train/celex54.oov
# fame/local/apply-g2p.py fame/dict/orig/celex-novo54.seqmodel.5 data/$train/celex54.oov > data/$train/oov.dict
#YU#

## data/lang and data/local/lang from fame/data/lang-4 and fame/data/local/lang

utils/validate_lang.pl --skip-determinization-check $lang

# monophones real    32m21.919s
echo "Creating training subset"
utils/subset_data_dir.sh data/$train 10000 data/$train-small

echo "Training monophone models"
steps/train_mono.sh --nj 20 --cmd "$train_cmd" data/$train-small $lang $mono

## triphones real    50m56.018s
echo "Training triphone models"
steps/align_si.sh --nj 20 --cmd "$train_cmd" data/$train $lang $mono $mono-ali
steps/train_deltas.sh --cmd "$train_cmd" 2000 10000 data/$train $lang $mono-ali $tri1

## lda real    46m50.742s
echo "Train lda mllt models"
#steps/align_si.sh --nj 20 --cmd "$train_cmd" data/$train $lang $tri1 $tri1-ali
steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    data/$train $lang $tri1-ali $tri2b || exit 1

## dla mllt sat real    79m32.428s
echo "Train lda mllt sat models and test"
steps/align_si.sh --nj 20 --cmd "$train_cmd" data/$train $lang $tri2b $tri2b-ali
steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
    data/$train $lang $tri2b-ali $tri3b 

## aligning real    25m24.512s
echo "Aligning with tri3b"
steps/align_fmllr.sh --nj 20 --cmd "$train_cmd" \
    data/$train $lang $tri3b $tri3b-ali

## train quickly real    29m26.134s
echo "Train a system quickly"
steps/train_quick.sh --cmd "$train_cmd" 4200 40000 \
    data/$train $lang $tri3b-ali $tri4b || exit 1;

else

echo "Aligning with tri3b"
steps/align_fmllr.sh --nj 20 --cmd "$train_cmd" \
    data/$train $lang $tri4b $tri4b-ali

fi
exit 0
