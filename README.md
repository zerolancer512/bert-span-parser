# bert-span-parser

This repo is based on:

- https://github.com/mitchellstern/minimal-span-parser
- https://github.com/junekihong/beam-span-parser


## Experiment

### Dataset

#### Vietnamese
Conducting experiments on the well-known and publicly available Vietnamese Treebank [corpus](https://link.springer.com/article/10.1007/s10579-015-9308-5?shared-article-renderer) from the VLSP project with bracketed structure format (similar to English Penn Treebank).

Constructing train/valid/test sets with 18:1:1 ratio.

### Evaluation Metric

<img src="https://render.githubusercontent.com/render/math?math=Precision = \frac{|T \cap T^*|}{|T|}">

<img src="https://render.githubusercontent.com/render/math?math=Recall = \frac{|T \cap T^*|}{|T^*|}">

<img src="https://render.githubusercontent.com/render/math?math=F1 = \frac{2 \times Precision \times Recall}{Precision\ %2B\ Recall}">

Where `T` is predicted tree (<img src="https://render.githubusercontent.com/render/math?math=T := ((i_t, j_t), l_t): 0 \leq t \leq |T|">, where <img src="https://render.githubusercontent.com/render/math?math=(i_t, j_t)"> is a span and <img src="https://render.githubusercontent.com/render/math?math=l_t"> is the corresponding label)  and `T*` is golden tree.

### Results

#### Vietnamese Treebank

| Model                       | F1 Dev | F1 Test                    |
|-----------------------------|--------|----------------------------|
| Shift-reduce parser (J.Cross & L.Huang, 2016) | 67.47 | 68.65 (R: 64.24, P: 73.70) |
| Beam parser (J.Hong & L.Huang, 2018) | 75.02 | 74.84 (R: 75.47, P: 74.22) |
| Minimal top-down parser (M.Stern et al., 2017) | 74.18 | 74.36 (R: 74.02, P: 74.70) |
| Minimal chart parser (M.Stern et al., 2017) | 75.24 | 76.14 (R: 75.04, P: 77.27) |
| Fasttext minimal parser (our test) | 75.35 | 76.30 (R: 76.45, P: 76.14) |
| Using BERT as feature (our work)       | 79.49  | 79.82 (R: 78.29; P: 81.41) |
| Using BERT with fine-tuning (our work) | 80.95  | 81.29 (R: 80.47, P: 82.12) |
