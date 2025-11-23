"""
Enhanced Model Evaluation Script for PocketSage
Includes confusion matrix visualization and comprehensive metrics reporting.
"""

import os
import json
import yaml
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from typing import List, Dict, Tuple, Any, Optional
from datetime import datetime
from pathlib import Path
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report
)
import pandas as pd
from dotenv import load_dotenv

# Import normalization and training modules
import sys
from pathlib import Path

# Add project paths
project_root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(0, str(project_root / 'api-endpoints'))
sys.path.insert(0, str(project_root / 'evaluation'))

from normalization import ReceiptNormalizer
from gemini_retraining import GeminiReceiptTrainer

# Load environment variables
load_dotenv()

# Set style for plots
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10


class ModelEvaluator:
    """
    Enhanced model evaluator with visualization capabilities.
    """
    
    def __init__(self, config_path: str = "evaluation/fine_tuning_config.yaml"):
        """Initialize evaluator with configuration."""
        self.config = self._load_config(config_path)
        self.normalizer = ReceiptNormalizer()
        self.trainer = GeminiReceiptTrainer(
            model_name=self.config['model']['base_model']
        )
        self.output_dir = Path(self.config['output']['output_directory'])
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Create timestamp for this evaluation run
        self.timestamp = datetime.now().strftime(self.config['output']['timestamp_format'])
        self.run_id = f"{self.config['output']['file_prefix']}_{self.timestamp}"
    
    def _load_config(self, config_path: str) -> Dict:
        """Load configuration from YAML file."""
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    
    def evaluate(
        self,
        training_data: List[Dict],
        test_data: List[Dict],
        use_few_shot: bool = True
    ) -> Dict[str, Any]:
        """
        Comprehensive model evaluation.
        
        Args:
            training_data: Training examples for few-shot learning
            test_data: Test examples with true labels
            use_few_shot: Whether to use few-shot learning
            
        Returns:
            Complete evaluation metrics dictionary
        """
        print("=" * 80)
        print("COMPREHENSIVE MODEL EVALUATION")
        print("=" * 80)
        print(f"Test set size: {len(test_data)}")
        print(f"Training examples: {len(training_data)}")
        print(f"Method: {'Few-shot learning' if use_few_shot else 'Zero-shot'}")
        print()
        
        # Normalize test data if normalization is enabled
        if self.config['normalization']['enabled']:
            print("Normalizing test data...")
            for example in test_data:
                if 'parsedData' in example and 'raw' in example['parsedData']:
                    example['parsedData']['raw'] = self.normalizer.normalize_receipt(
                        example['parsedData']['raw']
                    )
        
        # Run evaluation using trainer
        metrics = self.trainer.evaluate_model(
            training_data=training_data,
            test_data=test_data,
            use_few_shot=use_few_shot
        )
        
        # Add additional analysis
        metrics['evaluation_config'] = {
            'normalization_enabled': self.config['normalization']['enabled'],
            'few_shot_examples': len(training_data) if use_few_shot else 0,
            'timestamp': self.timestamp,
        }
        
        # Generate visualizations
        self._generate_confusion_matrix(metrics)
        self._generate_metrics_plot(metrics)
        self._generate_per_category_plot(metrics)
        
        # Save results
        self._save_results(metrics)
        
        return metrics
    
    def _generate_confusion_matrix(self, metrics: Dict[str, Any]):
        """Generate and save confusion matrix visualization."""
        cm = np.array(metrics['confusion_matrix'])
        categories = self.trainer.categories
        
        # Create figure
        fig, ax = plt.subplots(figsize=(12, 10))
        
        # Normalize confusion matrix for percentages
        cm_normalized = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]
        cm_normalized = np.nan_to_num(cm_normalized)  # Handle division by zero
        
        # Create heatmap
        sns.heatmap(
            cm_normalized,
            annot=True,
            fmt='.2%',
            cmap='Blues',
            xticklabels=[cat[:10] for cat in categories],
            yticklabels=[cat[:10] for cat in categories],
            ax=ax,
            cbar_kws={'label': 'Percentage'}
        )
        
        ax.set_xlabel('Predicted Category', fontsize=12, fontweight='bold')
        ax.set_ylabel('True Category', fontsize=12, fontweight='bold')
        ax.set_title('Confusion Matrix (Normalized)', fontsize=14, fontweight='bold', pad=20)
        
        plt.tight_layout()
        
        # Save figure
        cm_path = self.output_dir / f"{self.run_id}_confusion_matrix.png"
        plt.savefig(cm_path, dpi=300, bbox_inches='tight')
        print(f"Confusion matrix saved to: {cm_path}")
        
        # Also save raw counts version
        fig2, ax2 = plt.subplots(figsize=(12, 10))
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
        cm_counts_path = self.output_dir / f"{self.run_id}_confusion_matrix_counts.png"
        plt.savefig(cm_counts_path, dpi=300, bbox_inches='tight')
        plt.close('all')
    
    def _generate_metrics_plot(self, metrics: Dict[str, Any]):
        """Generate overall metrics visualization."""
        overall = metrics['overall']
        
        fig, ax = plt.subplots(figsize=(10, 6))
        
        metric_names = ['Accuracy', 'Precision', 'Recall', 'F1 Score']
        metric_values = [
            overall['accuracy'],
            overall['precision'],
            overall['recall'],
            overall['f1_score']
        ]
        
        colors = ['#2ecc71', '#3498db', '#9b59b6', '#e74c3c']
        bars = ax.bar(metric_names, metric_values, color=colors, alpha=0.8, edgecolor='black')
        
        # Add value labels on bars
        for bar, value in zip(bars, metric_values):
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{value:.3f}',
                   ha='center', va='bottom', fontweight='bold', fontsize=11)
        
        # Add target line
        target = self.config['evaluation']['target_metrics']['macro_f1_score']
        ax.axhline(y=target, color='red', linestyle='--', linewidth=2, 
                  label=f'Target F1: {target}', alpha=0.7)
        
        ax.set_ylabel('Score', fontsize=12, fontweight='bold')
        ax.set_title('Overall Model Performance Metrics', fontsize=14, fontweight='bold', pad=20)
        ax.set_ylim([0, 1.1])
        ax.legend()
        ax.grid(axis='y', alpha=0.3)
        
        plt.tight_layout()
        
        metrics_path = self.output_dir / f"{self.run_id}_overall_metrics.png"
        plt.savefig(metrics_path, dpi=300, bbox_inches='tight')
        print(f"Overall metrics plot saved to: {metrics_path}")
        plt.close()
    
    def _generate_per_category_plot(self, metrics: Dict[str, Any]):
        """Generate per-category metrics visualization."""
        per_category = metrics['per_category']
        categories = list(per_category.keys())
        
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
                if height > 0.01:  # Only label if significant
                    ax.text(bar.get_x() + bar.get_width()/2., height,
                           f'{height:.2f}',
                           ha='center', va='bottom', fontsize=9)
        
        # Add target line
        target = self.config['evaluation']['target_metrics']['per_category_f1_min']
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
        
        per_cat_path = self.output_dir / f"{self.run_id}_per_category_metrics.png"
        plt.savefig(per_cat_path, dpi=300, bbox_inches='tight')
        print(f"Per-category metrics plot saved to: {per_cat_path}")
        plt.close()
    
    def _save_results(self, metrics: Dict[str, Any]):
        """Save evaluation results in multiple formats."""
        # Save JSON
        json_path = self.output_dir / f"{self.run_id}_results.json"
        with open(json_path, 'w') as f:
            json.dump(metrics, f, indent=2)
        print(f"Results saved to: {json_path}")
        
        # Save CSV for per-category metrics
        per_category = metrics['per_category']
        df = pd.DataFrame([
            {
                'category': cat,
                'precision': vals['precision'],
                'recall': vals['recall'],
                'f1_score': vals['f1_score']
            }
            for cat, vals in per_category.items()
        ])
        
        csv_path = self.output_dir / f"{self.run_id}_per_category_metrics.csv"
        df.to_csv(csv_path, index=False)
        print(f"Per-category metrics CSV saved to: {csv_path}")
        
        # Save classification report as text
        report_path = self.output_dir / f"{self.run_id}_classification_report.txt"
        with open(report_path, 'w') as f:
            f.write("=" * 80 + "\n")
            f.write("POCKETSAGE MODEL EVALUATION REPORT\n")
            f.write("=" * 80 + "\n\n")
            f.write(f"Model: {metrics['model_name']}\n")
            f.write(f"Timestamp: {metrics['timestamp']}\n")
            f.write(f"Test Set Size: {metrics['test_size']}\n")
            f.write(f"Training Examples: {metrics['training_size']}\n\n")
            
            f.write("-" * 80 + "\n")
            f.write("OVERALL METRICS\n")
            f.write("-" * 80 + "\n")
            overall = metrics['overall']
            f.write(f"Accuracy:  {overall['accuracy']:.4f} ({overall['accuracy']*100:.2f}%)\n")
            f.write(f"Precision: {overall['precision']:.4f} ({overall['precision']*100:.2f}%)\n")
            f.write(f"Recall:    {overall['recall']:.4f} ({overall['recall']*100:.2f}%)\n")
            f.write(f"F1 Score:  {overall['f1_score']:.4f} ({overall['f1_score']*100:.2f}%)\n\n")
            
            f.write("-" * 80 + "\n")
            f.write("PER-CATEGORY METRICS\n")
            f.write("-" * 80 + "\n")
            f.write(f"{'Category':<20} {'Precision':<12} {'Recall':<12} {'F1 Score':<12}\n")
            f.write("-" * 80 + "\n")
            for cat, vals in per_category.items():
                f.write(f"{cat:<20} {vals['precision']:<12.4f} {vals['recall']:<12.4f} {vals['f1_score']:<12.4f}\n")
            
            f.write("\n" + "=" * 80 + "\n")
        
        print(f"Classification report saved to: {report_path}")
    
    def print_summary(self, metrics: Dict[str, Any]):
        """Print a summary of evaluation results."""
        self.trainer.print_evaluation_report(metrics)
        
        # Additional summary
        print("\n" + "=" * 80)
        print("EVALUATION SUMMARY")
        print("=" * 80)
        print(f"✓ Overall F1 Score: {metrics['overall']['f1_score']:.4f}")
        print(f"✓ Target F1 Score: {self.config['evaluation']['target_metrics']['macro_f1_score']:.4f}")
        
        target_met = metrics['overall']['f1_score'] >= self.config['evaluation']['target_metrics']['macro_f1_score']
        print(f"✓ Target Met: {'YES' if target_met else 'NO'}")
        
        # Count categories meeting minimum F1
        min_f1 = self.config['evaluation']['target_metrics']['per_category_f1_min']
        categories_meeting_target = sum(
            1 for cat, vals in metrics['per_category'].items()
            if vals['f1_score'] >= min_f1
        )
        total_categories = len(metrics['per_category'])
        print(f"✓ Categories meeting F1 ≥ {min_f1}: {categories_meeting_target}/{total_categories}")
        print("=" * 80)


def main():
    """Main evaluation function."""
    # Initialize evaluator
    evaluator = ModelEvaluator()
    
    # Load data (this would typically come from Firestore or a data file)
    # For demonstration, we'll use the trainer's mock data loading
    from gemini_retraining import load_receipts_from_firestore
    
    print("Loading receipt data...")
    all_receipts = load_receipts_from_firestore(limit=100)
    
    # Prepare training data
    training_examples = evaluator.trainer.prepare_training_data(all_receipts)
    
    if len(training_examples) < 2:
        print("Insufficient data. Using mock examples...")
        training_examples = [
            {
                'input': 'Vendor: Grocery Store\nTotal: 150.50\nItems:\n  - Milk: 50\n  - Bread: 30',
                'output': 'groceries',
                'metadata': {}
            },
            {
                'input': 'Vendor: Restaurant\nTotal: 500\nItems:\n  - Pizza: 300\n  - Drinks: 200',
                'output': 'dining',
                'metadata': {}
            },
            {
                'input': 'Vendor: Gas Station\nTotal: 2000\nItems:\n  - Fuel: 2000',
                'output': 'transportation',
                'metadata': {}
            },
            {
                'input': 'Vendor: Electricity Board\nTotal: 1500\nItems:\n  - Electricity Bill: 1500',
                'output': 'utilities',
                'metadata': {}
            },
            {
                'input': 'Vendor: Hotel\nTotal: 5000\nItems:\n  - Room: 5000',
                'output': 'travel',
                'metadata': {}
            },
        ]
    
    # Split data
    split_idx = int(len(training_examples) * evaluator.config['training']['train_split'])
    train_set = training_examples[:split_idx]
    test_set = training_examples[split_idx:]
    
    if len(test_set) == 0:
        test_set = train_set[:min(5, len(train_set))]
    
    print(f"Training set: {len(train_set)} examples")
    print(f"Test set: {len(test_set)} examples\n")
    
    # Run evaluation
    metrics = evaluator.evaluate(
        training_data=train_set,
        test_data=test_set,
        use_few_shot=True
    )
    
    # Print summary
    evaluator.print_summary(metrics)
    
    print("\n" + "=" * 80)
    print("Evaluation complete! Check the results directory for detailed outputs.")
    print("=" * 80)


if __name__ == "__main__":
    main()

