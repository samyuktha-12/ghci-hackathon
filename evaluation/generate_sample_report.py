"""
Generate Sample Evaluation Report with Visualizations
This script creates sample evaluation results and generates all visualizations.
"""

import os
import json
import yaml
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from datetime import datetime
from sklearn.metrics import confusion_matrix
import pandas as pd

# Set style for plots
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10

# Create results directory
results_dir = Path(__file__).parent / 'results'
results_dir.mkdir(parents=True, exist_ok=True)

# Load configuration
config_path = Path(__file__).parent / 'fine_tuning_config.yaml'
with open(config_path, 'r') as f:
    config = yaml.safe_load(f)

# Sample categories
categories = [
    "groceries",
    "utilities",
    "transportation",
    "dining",
    "travel",
    "reimbursement",
    "home"
]

# Generate sample confusion matrix with realistic values
np.random.seed(42)
n_samples = 200
n_categories = len(categories)

# Create realistic confusion matrix
# Diagonal should be high (correct predictions)
# Some off-diagonal confusion for similar categories
cm = np.zeros((n_categories, n_categories), dtype=int)

# True labels distribution (realistic)
true_distribution = [45, 12, 28, 35, 18, 8, 15]  # Total: 161

# Generate confusion matrix
for i, true_count in enumerate(true_distribution):
    # Most predictions are correct (diagonal)
    correct = int(true_count * 0.92)  # 92% accuracy
    cm[i, i] = correct
    
    # Some confusion with similar categories
    remaining = true_count - correct
    
    if i == 0:  # groceries
        # Some confusion with home
        cm[i, 6] = int(remaining * 0.5)
        remaining -= cm[i, 6]
        # Some confusion with dining
        cm[i, 3] = remaining
    elif i == 1:  # utilities
        # Some confusion with home
        cm[i, 6] = remaining
    elif i == 2:  # transportation
        # Some confusion with travel
        cm[i, 4] = remaining
    elif i == 3:  # dining
        # Some confusion with groceries
        cm[i, 0] = remaining
    elif i == 4:  # travel
        # Some confusion with transportation
        cm[i, 2] = remaining
    elif i == 5:  # reimbursement
        # More confusion (lower performance)
        cm[i, i] = int(true_count * 0.86)  # 86% accuracy
        remaining = true_count - cm[i, i]
        # Confusion with travel and home
        cm[i, 4] = int(remaining * 0.5)
        cm[i, 6] = remaining - cm[i, 4]
    elif i == 6:  # home
        # Some confusion with groceries
        cm[i, 0] = remaining

# Calculate metrics from confusion matrix
y_true = []
y_pred = []

for i in range(n_categories):
    for j in range(n_categories):
        count = cm[i, j]
        for _ in range(count):
            y_true.append(categories[i])
            y_pred.append(categories[j])

# Calculate per-category metrics
from sklearn.metrics import precision_score, recall_score, f1_score

precision_per_class = precision_score(y_true, y_pred, average=None, zero_division=0, labels=categories)
recall_per_class = recall_score(y_true, y_pred, average=None, zero_division=0, labels=categories)
f1_per_class = f1_score(y_true, y_pred, average=None, zero_division=0, labels=categories)

# Overall metrics
accuracy = np.trace(cm) / np.sum(cm)
precision_weighted = precision_score(y_true, y_pred, average='weighted', zero_division=0)
recall_weighted = recall_score(y_true, y_pred, average='weighted', zero_division=0)
f1_weighted = f1_score(y_true, y_pred, average='weighted', zero_division=0)
f1_macro = f1_score(y_true, y_pred, average='macro', zero_division=0)
f1_micro = f1_score(y_true, y_pred, average='micro', zero_division=0)

# Create metrics dictionary
metrics = {
    'model_name': config['model']['base_model'],
    'timestamp': datetime.utcnow().isoformat(),
    'test_size': len(y_true),
    'training_size': 500,
    'overall': {
        'accuracy': float(accuracy),
        'precision': float(precision_weighted),
        'recall': float(recall_weighted),
        'f1_score': float(f1_weighted),
        'f1_macro': float(f1_macro),
        'f1_micro': float(f1_micro)
    },
    'per_category': {
        category: {
            'precision': float(prec),
            'recall': float(rec),
            'f1_score': float(f1_val)
        }
        for category, prec, rec, f1_val in zip(categories, precision_per_class, recall_per_class, f1_per_class)
    },
    'confusion_matrix': cm.tolist(),
    'evaluation_config': {
        'normalization_enabled': True,
        'few_shot_examples': 5,
        'timestamp': datetime.now().strftime('%Y%m%d_%H%M%S')
    }
}

print("=" * 80)
print("GENERATING SAMPLE EVALUATION REPORT")
print("=" * 80)
print(f"Test samples: {len(y_true)}")
print(f"Categories: {len(categories)}")
print()

# 1. Generate Confusion Matrix Visualization
print("1. Generating confusion matrix visualizations...")

# Normalized confusion matrix
cm_normalized = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]
cm_normalized = np.nan_to_num(cm_normalized)

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(20, 8))

# Normalized heatmap
sns.heatmap(
    cm_normalized,
    annot=True,
    fmt='.2%',
    cmap='Blues',
    xticklabels=[cat[:10] for cat in categories],
    yticklabels=[cat[:10] for cat in categories],
    ax=ax1,
    cbar_kws={'label': 'Percentage'},
    vmin=0,
    vmax=1
)
ax1.set_xlabel('Predicted Category', fontsize=12, fontweight='bold')
ax1.set_ylabel('True Category', fontsize=12, fontweight='bold')
ax1.set_title('Confusion Matrix (Normalized)', fontsize=14, fontweight='bold', pad=20)

# Raw counts heatmap
sns.heatmap(
    cm,
    annot=True,
    fmt='d',
    cmap='Blues',
    xticklabels=[cat[:10] for cat in categories],
    yticklabels=[cat[:10] for cat in categories],
    ax=ax2,
    cbar_kws={'label': 'Count'}
)
ax2.set_xlabel('Predicted Category', fontsize=12, fontweight='bold')
ax2.set_ylabel('True Category', fontsize=12, fontweight='bold')
ax2.set_title('Confusion Matrix (Raw Counts)', fontsize=14, fontweight='bold', pad=20)

plt.tight_layout()
cm_path = results_dir / 'sample_confusion_matrix.png'
plt.savefig(cm_path, dpi=300, bbox_inches='tight')
print(f"   ✓ Saved: {cm_path}")
plt.close()

# 2. Generate Overall Metrics Plot
print("2. Generating overall metrics visualization...")

fig, ax = plt.subplots(figsize=(10, 6))

metric_names = ['Accuracy', 'Precision', 'Recall', 'F1 Score (Weighted)', 'F1 (Macro)', 'F1 (Micro)']
metric_values = [
    metrics['overall']['accuracy'],
    metrics['overall']['precision'],
    metrics['overall']['recall'],
    metrics['overall']['f1_score'],
    metrics['overall']['f1_macro'],
    metrics['overall']['f1_micro']
]

colors = ['#2ecc71', '#3498db', '#9b59b6', '#e74c3c', '#f39c12', '#1abc9c']
bars = ax.bar(metric_names, metric_values, color=colors, alpha=0.8, edgecolor='black')

# Add value labels on bars
for bar, value in zip(bars, metric_values):
    height = bar.get_height()
    ax.text(bar.get_x() + bar.get_width()/2., height,
           f'{value:.3f}',
           ha='center', va='bottom', fontweight='bold', fontsize=10)

# Add target line
target = config['evaluation']['target_metrics']['macro_f1_score']
ax.axhline(y=target, color='red', linestyle='--', linewidth=2, 
          label=f'Target F1: {target}', alpha=0.7)

ax.set_ylabel('Score', fontsize=12, fontweight='bold')
ax.set_title('Overall Model Performance Metrics', fontsize=14, fontweight='bold', pad=20)
ax.set_ylim([0, 1.1])
ax.legend()
ax.grid(axis='y', alpha=0.3)
plt.xticks(rotation=45, ha='right')

plt.tight_layout()
metrics_path = results_dir / 'sample_overall_metrics.png'
plt.savefig(metrics_path, dpi=300, bbox_inches='tight')
print(f"   ✓ Saved: {metrics_path}")
plt.close()

# 3. Generate Per-Category Metrics Plot
print("3. Generating per-category metrics visualization...")

per_category = metrics['per_category']
precision_vals = [per_category[cat]['precision'] for cat in categories]
recall_vals = [per_category[cat]['recall'] for cat in categories]
f1_vals = [per_category[cat]['f1_score'] for cat in categories]

x = np.arange(len(categories))
width = 0.25

fig, ax = plt.subplots(figsize=(14, 8))

bars1 = ax.bar(x - width, precision_vals, width, label='Precision', 
              color='#3498db', alpha=0.8, edgecolor='black')
bars2 = ax.bar(x, recall_vals, width, label='Recall', 
              color='#2ecc71', alpha=0.8, edgecolor='black')
bars3 = ax.bar(x + width, f1_vals, width, label='F1 Score', 
              color='#e74c3c', alpha=0.8, edgecolor='black')

# Add value labels
for bars in [bars1, bars2, bars3]:
    for bar in bars:
        height = bar.get_height()
        if height > 0.01:
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{height:.2f}',
                   ha='center', va='bottom', fontsize=9)

# Add target line
target = config['evaluation']['target_metrics']['per_category_f1_min']
ax.axhline(y=target, color='red', linestyle='--', linewidth=2, 
          label=f'Target F1: {target}', alpha=0.7)

ax.set_xlabel('Category', fontsize=12, fontweight='bold')
ax.set_ylabel('Score', fontsize=12, fontweight='bold')
ax.set_title('Per-Category Performance Metrics', fontsize=14, fontweight='bold', pad=20)
ax.set_xticks(x)
ax.set_xticklabels([cat[:12] for cat in categories], rotation=45, ha='right')
ax.set_ylim([0, 1.1])
ax.legend()
ax.grid(axis='y', alpha=0.3)

plt.tight_layout()
per_cat_path = results_dir / 'sample_per_category_metrics.png'
plt.savefig(per_cat_path, dpi=300, bbox_inches='tight')
print(f"   ✓ Saved: {per_cat_path}")
plt.close()

# 4. Generate Per-Category F1 Score Comparison
print("4. Generating per-category F1 score comparison...")

f1_scores = [per_category[cat]['f1_score'] for cat in categories]
meets_target = [f1 >= target for f1 in f1_scores]

fig, ax = plt.subplots(figsize=(12, 6))

colors_bar = ['#2ecc71' if meets else '#e74c3c' for meets in meets_target]
bars = ax.barh(categories, f1_scores, color=colors_bar, alpha=0.8, edgecolor='black')

# Add value labels
for i, (bar, score) in enumerate(zip(bars, f1_scores)):
    width = bar.get_width()
    ax.text(width, bar.get_y() + bar.get_height()/2.,
           f'{score:.3f}',
           ha='left' if width < 0.1 else 'right', va='center', fontweight='bold', fontsize=10)

# Add target line
ax.axvline(x=target, color='red', linestyle='--', linewidth=2, 
          label=f'Target F1: {target}', alpha=0.7)

ax.set_xlabel('F1 Score', fontsize=12, fontweight='bold')
ax.set_title('Per-Category F1 Score Comparison', fontsize=14, fontweight='bold', pad=20)
ax.set_xlim([0, 1.1])
ax.legend()
ax.grid(axis='x', alpha=0.3)

plt.tight_layout()
f1_comparison_path = results_dir / 'sample_f1_comparison.png'
plt.savefig(f1_comparison_path, dpi=300, bbox_inches='tight')
print(f"   ✓ Saved: {f1_comparison_path}")
plt.close()

# 5. Save JSON results
print("5. Saving evaluation results...")
json_path = results_dir / 'sample_evaluation_results.json'
with open(json_path, 'w') as f:
    json.dump(metrics, f, indent=2)
print(f"   ✓ Saved: {json_path}")

# 6. Save CSV for per-category metrics
print("6. Saving per-category metrics CSV...")
df = pd.DataFrame([
    {
        'Category': cat,
        'Precision': vals['precision'],
        'Recall': vals['recall'],
        'F1 Score': vals['f1_score'],
        'Meets Target (F1 ≥ 0.90)': 'Yes' if vals['f1_score'] >= target else 'No'
    }
    for cat, vals in per_category.items()
])
csv_path = results_dir / 'sample_per_category_metrics.csv'
df.to_csv(csv_path, index=False)
print(f"   ✓ Saved: {csv_path}")

# 7. Generate text report
print("7. Generating classification report...")
report_path = results_dir / 'sample_classification_report.txt'
with open(report_path, 'w') as f:
    f.write("=" * 80 + "\n")
    f.write("POCKETSAGE MODEL EVALUATION REPORT - SAMPLE RESULTS\n")
    f.write("=" * 80 + "\n\n")
    f.write(f"Model: {metrics['model_name']}\n")
    f.write(f"Timestamp: {metrics['timestamp']}\n")
    f.write(f"Test Set Size: {metrics['test_size']}\n")
    f.write(f"Training Examples: {metrics['training_size']}\n\n")
    
    f.write("-" * 80 + "\n")
    f.write("OVERALL METRICS\n")
    f.write("-" * 80 + "\n")
    overall = metrics['overall']
    f.write(f"Accuracy:      {overall['accuracy']:.4f} ({overall['accuracy']*100:.2f}%)\n")
    f.write(f"Precision:     {overall['precision']:.4f} ({overall['precision']*100:.2f}%)\n")
    f.write(f"Recall:        {overall['recall']:.4f} ({overall['recall']*100:.2f}%)\n")
    f.write(f"F1 Score:      {overall['f1_score']:.4f} ({overall['f1_score']*100:.2f}%)\n")
    f.write(f"F1 (Macro):    {overall['f1_macro']:.4f} ({overall['f1_macro']*100:.2f}%)\n")
    f.write(f"F1 (Micro):    {overall['f1_micro']:.4f} ({overall['f1_micro']*100:.2f}%)\n\n")
    
    f.write("-" * 80 + "\n")
    f.write("PER-CATEGORY METRICS\n")
    f.write("-" * 80 + "\n")
    f.write(f"{'Category':<20} {'Precision':<12} {'Recall':<12} {'F1 Score':<12} {'Meets Target':<12}\n")
    f.write("-" * 80 + "\n")
    for cat, vals in per_category.items():
        meets = 'Yes' if vals['f1_score'] >= target else 'No'
        f.write(f"{cat:<20} {vals['precision']:<12.4f} {vals['recall']:<12.4f} {vals['f1_score']:<12.4f} {meets:<12}\n")
    
    f.write("\n" + "=" * 80 + "\n")
    f.write("TARGET METRICS\n")
    f.write("=" * 80 + "\n")
    f.write(f"Target Macro F1: {target:.4f}\n")
    f.write(f"Target Met: {'YES' if overall['f1_macro'] >= target else 'NO'}\n")
    f.write(f"Categories meeting F1 ≥ {target}: {sum(1 for v in per_category.values() if v['f1_score'] >= target)}/{len(categories)}\n")
    f.write("\n" + "=" * 80 + "\n")

print(f"   ✓ Saved: {report_path}")

print("\n" + "=" * 80)
print("SAMPLE EVALUATION REPORT GENERATION COMPLETE!")
print("=" * 80)
print(f"\nAll files saved to: {results_dir}")
print("\nGenerated files:")
print(f"  - sample_confusion_matrix.png")
print(f"  - sample_overall_metrics.png")
print(f"  - sample_per_category_metrics.png")
print(f"  - sample_f1_comparison.png")
print(f"  - sample_evaluation_results.json")
print(f"  - sample_per_category_metrics.csv")
print(f"  - sample_classification_report.txt")

