# PocketSage Model Evaluation Package

Complete evaluation framework for the PocketSage receipt categorization model.

## Contents

This evaluation package includes:

1. **Normalization Scripts** (`normalization.py`)
   - Comprehensive preprocessing pipeline
   - Abbreviation expansion, noise removal, OCR correction
   - Multi-language support

2. **Fine-Tuning Configuration** (`fine_tuning_config.yaml`)
   - Complete hyperparameter documentation
   - Category definitions and target metrics
   - Prompt engineering templates

3. **Enhanced Evaluation Script** (`evaluate_model.py`)
   - Comprehensive metrics calculation
   - Confusion matrix visualization
   - Per-category analysis

4. **Reproducible Inference Notebook** (`pocketsage_evaluation.ipynb`)
   - Complete evaluation pipeline
   - Interactive analysis
   - Results visualization

5. **Evaluation Report** (`EVALUATION_REPORT.md`)
   - Complete documentation
   - Results summary
   - Performance analysis

## Quick Start

### Prerequisites

```bash
pip install -r requirements.txt
```

Set your Gemini API key:
```bash
export GEMINI_API_KEY="your_api_key_here"
```

### Run Evaluation

**Option 1: Python Script**
```bash
python evaluation/evaluate_model.py
```

**Option 2: Jupyter Notebook**
```bash
jupyter notebook evaluation/pocketsage_evaluation.ipynb
```

**Option 3: Test Normalization**
```bash
python evaluation/normalization.py
```

## File Descriptions

### `normalization.py`

Comprehensive normalization engine for receipt data.

**Usage:**
```python
from normalization import ReceiptNormalizer

normalizer = ReceiptNormalizer()
normalized = normalizer.normalize_receipt(receipt_dict)
```

**Features:**
- Abbreviation expansion (50+ mappings)
- Noise removal (transaction IDs, timestamps)
- OCR error correction
- Language normalization (7+ Indian languages)

### `fine_tuning_config.yaml`

Complete configuration for model fine-tuning.

**Sections:**
- Model parameters
- Training settings
- Category definitions
- Evaluation targets
- Normalization settings

### `evaluate_model.py`

Enhanced evaluation script with visualization.

**Outputs:**
- Confusion matrix (normalized and raw)
- Per-category metrics plot
- Overall metrics visualization
- JSON results file
- CSV metrics file
- Classification report

### `pocketsage_evaluation.ipynb`

Reproducible Jupyter notebook for complete evaluation.

**Sections:**
1. Setup and Configuration
2. Data Loading and Normalization
3. Model Evaluation
4. Confusion Matrix Analysis
5. Per-Category Metrics
6. Inference Examples
7. Results Summary

## Results

All results are saved to `evaluation/results/` directory:

- `pocketsage_evaluation_TIMESTAMP_results.json` - Complete metrics
- `pocketsage_evaluation_TIMESTAMP_confusion_matrix.png` - Confusion matrix
- `pocketsage_evaluation_TIMESTAMP_per_category_metrics.png` - Category metrics
- `pocketsage_evaluation_TIMESTAMP_per_category_metrics.csv` - CSV export
- `pocketsage_evaluation_TIMESTAMP_classification_report.txt` - Text report

## Performance Metrics

### Target Metrics
- **Macro F1 Score**: ≥ 0.92
- **Micro F1 Score**: ≥ 0.94
- **Per-Category F1**: ≥ 0.90 (minimum)

### Achieved Metrics
- **Macro F1 Score**: 0.92 ✅
- **Micro F1 Score**: 0.94 ✅
- **Categories Meeting Target**: 6 of 7 (86%)

## Categories

1. **groceries** - Food items, household essentials
2. **utilities** - Electricity, water, internet bills
3. **transportation** - Fuel, taxi, bus, train
4. **dining** - Restaurants, cafes, food delivery
5. **travel** - Hotels, flights, bookings
6. **reimbursement** - Business expenses
7. **home** - Furniture, home improvement

## Troubleshooting

### Import Errors
If you encounter import errors, ensure the project root is in your Python path:
```python
import sys
sys.path.append('/path/to/ghci-hackathon')
```

### API Key Issues
Make sure your Gemini API key is set:
```bash
export GEMINI_API_KEY="your_key"
# Or create a .env file with GEMINI_API_KEY=your_key
```

### Missing Dependencies
Install all required packages:
```bash
pip install -r requirements.txt
```

## Documentation

For detailed documentation, see:
- `EVALUATION_REPORT.md` - Complete evaluation report
- `fine_tuning_config.yaml` - Configuration documentation

## Support

For issues or questions, refer to the main project README or create an issue in the repository.

