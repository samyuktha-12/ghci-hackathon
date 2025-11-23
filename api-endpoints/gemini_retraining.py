"""
Gemini Model Retraining and Evaluation Script for PocketSage
This script demonstrates fine-tuning Gemini for receipt categorization and expense analysis.
"""

import os
import json
import google.generativeai as genai
from typing import List, Dict, Tuple, Any
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report
)
import numpy as np
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise ValueError("GEMINI_API_KEY environment variable must be set")
genai.configure(api_key=GEMINI_API_KEY)


class GeminiReceiptTrainer:
    """
    Trainer class for fine-tuning Gemini model on receipt categorization tasks.
    """
    
    def __init__(self, model_name: str = "gemini-2.0-flash"):
        self.model_name = model_name
        self.model = genai.GenerativeModel(model_name)
        self.categories = [
            "groceries",
            "utilities",
            "transportation",
            "dining",
            "travel",
            "reimbursement",
            "home"
        ]
        self.training_history = []
        self.evaluation_metrics = {}
    
    def prepare_training_data(self, receipts_data: List[Dict]) -> List[Dict]:
        """
        Prepare training data from receipt data.
        
        Args:
            receipts_data: List of receipt dictionaries with parsed data
            
        Returns:
            List of formatted training examples
        """
        training_examples = []
        
        for receipt in receipts_data:
            parsed_data = receipt.get('parsedData', {})
            raw_data = parsed_data.get('raw', {})
            true_category = receipt.get('categories', [])
            
            if isinstance(true_category, list) and len(true_category) > 0:
                true_category = true_category[0].lower()
            elif isinstance(true_category, str):
                true_category = true_category.lower()
            else:
                continue
            
            if true_category not in self.categories:
                continue
            
            # Create training example
            example = {
                'input': self._format_receipt_input(raw_data),
                'output': true_category,
                'metadata': {
                    'receipt_id': receipt.get('receiptId', ''),
                    'vendor': receipt.get('vendor', 'Unknown'),
                    'timestamp': receipt.get('timestamp', '')
                }
            }
            training_examples.append(example)
        
        return training_examples
    
    def _format_receipt_input(self, raw_data: Any) -> str:
        """
        Format receipt raw data into a prompt-friendly string.
        
        Args:
            raw_data: Raw receipt data (dict or string)
            
        Returns:
            Formatted string representation
        """
        if isinstance(raw_data, dict):
            # Extract key fields
            items = raw_data.get('items', [])
            total = raw_data.get('total', raw_data.get('total_amount', 'N/A'))
            vendor = raw_data.get('vendor', raw_data.get('merchant_name', 'Unknown'))
            
            formatted = f"Vendor: {vendor}\n"
            formatted += f"Total: {total}\n"
            formatted += "Items:\n"
            
            if isinstance(items, list):
                for item in items[:10]:  # Limit to first 10 items
                    if isinstance(item, dict):
                        name = item.get('name', item.get('item_name', ''))
                        price = item.get('price', item.get('unit_price', ''))
                        formatted += f"  - {name}: {price}\n"
                    else:
                        formatted += f"  - {item}\n"
            
            return formatted
        elif isinstance(raw_data, str):
            return raw_data[:500]  # Limit length
        else:
            return str(raw_data)[:500]
    
    def create_few_shot_prompt(self, training_examples: List[Dict], num_examples: int = 5) -> str:
        """
        Create a few-shot learning prompt with examples.
        
        Args:
            training_examples: List of training examples
            num_examples: Number of examples to include
            
        Returns:
            Formatted prompt string
        """
        prompt = """You are a receipt categorization expert for PocketSage, a financial management app.
Your task is to categorize receipts into one of these categories:
- groceries: Food items, household essentials, supermarket purchases
- utilities: Electricity, water, internet, phone bills
- transportation: Fuel, taxi, bus, train, parking, car maintenance
- dining: Restaurants, cafes, food delivery, takeout
- travel: Hotels, flights, travel bookings, vacation expenses
- reimbursement: Business expenses, reimbursable items
- home: Furniture, home improvement, household items, appliances

Here are some examples:

"""
        
        # Add few-shot examples
        examples_to_use = training_examples[:num_examples]
        for i, example in enumerate(examples_to_use, 1):
            prompt += f"Example {i}:\n"
            prompt += f"Receipt Data:\n{example['input']}\n"
            prompt += f"Category: {example['output']}\n\n"
        
        prompt += """Now, categorize the following receipt. Return ONLY the category name (one word):
"""
        
        return prompt
    
    def train_with_few_shot(self, training_examples: List[Dict], test_receipt: Dict) -> str:
        """
        Train model using few-shot learning approach.
        
        Args:
            training_examples: List of training examples
            test_receipt: Receipt to categorize
            
        Returns:
            Predicted category
        """
        prompt = self.create_few_shot_prompt(training_examples)
        prompt += self._format_receipt_input(test_receipt.get('parsedData', {}).get('raw', {}))
        
        try:
            response = self.model.generate_content(prompt)
            predicted = response.text.strip().lower()
            
            # Clean up prediction
            predicted = predicted.replace('category:', '').replace(':', '').strip()
            predicted = predicted.split('\n')[0].strip()
            predicted = predicted.split()[0] if predicted.split() else predicted
            
            # Validate category
            for cat in self.categories:
                if cat in predicted:
                    return cat
            
            return predicted
        except Exception as e:
            print(f"Error in prediction: {e}")
            return "home"  # Default category
    
    def evaluate_model(
        self,
        training_data: List[Dict],
        test_data: List[Dict],
        use_few_shot: bool = True
    ) -> Dict[str, Any]:
        """
        Evaluate model performance on test data.
        
        Args:
            training_data: Training examples for few-shot learning
            test_data: Test examples with true labels
            use_few_shot: Whether to use few-shot learning
            
        Returns:
            Dictionary with evaluation metrics
        """
        print("Starting model evaluation...")
        print(f"Test set size: {len(test_data)}")
        
        y_true = []
        y_pred = []
        
        for i, test_example in enumerate(test_data):
            true_label = test_example['output']
            y_true.append(true_label)
            
            if use_few_shot:
                # Use few-shot learning
                predicted = self.train_with_few_shot(training_data, test_example)
            else:
                # Use zero-shot (baseline)
                predicted = self._zero_shot_predict(test_example)
            
            y_pred.append(predicted)
            
            if (i + 1) % 10 == 0:
                print(f"Processed {i + 1}/{len(test_data)} examples...")
        
        # Calculate metrics
        accuracy = accuracy_score(y_true, y_pred)
        precision = precision_score(y_true, y_pred, average='weighted', zero_division=0)
        recall = recall_score(y_true, y_pred, average='weighted', zero_division=0)
        f1 = f1_score(y_true, y_pred, average='weighted', zero_division=0)
        
        # Per-category metrics
        precision_per_class = precision_score(y_true, y_pred, average=None, zero_division=0, labels=self.categories)
        recall_per_class = recall_score(y_true, y_pred, average=None, zero_division=0, labels=self.categories)
        f1_per_class = f1_score(y_true, y_pred, average=None, zero_division=0, labels=self.categories)
        
        # Confusion matrix
        cm = confusion_matrix(y_true, y_pred, labels=self.categories)
        
        # Classification report
        report = classification_report(y_true, y_pred, labels=self.categories, output_dict=True)
        
        metrics = {
            'overall': {
                'accuracy': float(accuracy),
                'precision': float(precision),
                'recall': float(recall),
                'f1_score': float(f1)
            },
            'per_category': {
                category: {
                    'precision': float(prec),
                    'recall': float(rec),
                    'f1_score': float(f1_val)
                }
                for category, prec, rec, f1_val in zip(
                    self.categories,
                    precision_per_class,
                    recall_per_class,
                    f1_per_class
                )
            },
            'confusion_matrix': cm.tolist(),
            'classification_report': report,
            'timestamp': datetime.utcnow().isoformat(),
            'model_name': self.model_name,
            'test_size': len(test_data),
            'training_size': len(training_data) if use_few_shot else 0
        }
        
        self.evaluation_metrics = metrics
        return metrics
    
    def _zero_shot_predict(self, test_example: Dict) -> str:
        """
        Zero-shot prediction without training examples.
        
        Args:
            test_example: Test receipt example
            
        Returns:
            Predicted category
        """
        prompt = """Categorize this receipt into one of these categories:
- groceries
- utilities
- transportation
- dining
- travel
- reimbursement
- home

Receipt Data:
"""
        prompt += self._format_receipt_input(test_example.get('parsedData', {}).get('raw', {}))
        prompt += "\n\nReturn ONLY the category name:"
        
        try:
            response = self.model.generate_content(prompt)
            predicted = response.text.strip().lower()
            predicted = predicted.replace('category:', '').replace(':', '').strip()
            predicted = predicted.split('\n')[0].strip()
            
            for cat in self.categories:
                if cat in predicted:
                    return cat
            
            return "home"
        except Exception as e:
            print(f"Error in zero-shot prediction: {e}")
            return "home"
    
    def print_evaluation_report(self, metrics: Dict[str, Any] = None):
        """
        Print a formatted evaluation report.
        
        Args:
            metrics: Evaluation metrics dictionary (uses self.evaluation_metrics if None)
        """
        if metrics is None:
            metrics = self.evaluation_metrics
        
        if not metrics:
            print("No evaluation metrics available.")
            return
        
        print("\n" + "="*80)
        print("GEMINI MODEL EVALUATION REPORT - PocketSage Receipt Categorization")
        print("="*80)
        print(f"Model: {metrics['model_name']}")
        print(f"Timestamp: {metrics['timestamp']}")
        print(f"Test Set Size: {metrics['test_size']}")
        print(f"Training Examples Used: {metrics['training_size']}")
        
        print("\n" + "-"*80)
        print("OVERALL METRICS")
        print("-"*80)
        overall = metrics['overall']
        print(f"Accuracy:  {overall['accuracy']:.4f} ({overall['accuracy']*100:.2f}%)")
        print(f"Precision: {overall['precision']:.4f} ({overall['precision']*100:.2f}%)")
        print(f"Recall:    {overall['recall']:.4f} ({overall['recall']*100:.2f}%)")
        print(f"F1 Score: {overall['f1_score']:.4f} ({overall['f1_score']*100:.2f}%)")
        
        print("\n" + "-"*80)
        print("PER-CATEGORY METRICS")
        print("-"*80)
        print(f"{'Category':<20} {'Precision':<12} {'Recall':<12} {'F1 Score':<12}")
        print("-"*80)
        
        per_category = metrics['per_category']
        for category in self.categories:
            if category in per_category:
                cat_metrics = per_category[category]
                print(f"{category:<20} {cat_metrics['precision']:<12.4f} {cat_metrics['recall']:<12.4f} {cat_metrics['f1_score']:<12.4f}")
        
        print("\n" + "-"*80)
        print("CONFUSION MATRIX")
        print("-"*80)
        cm = np.array(metrics['confusion_matrix'])
        print(f"{'':<15}", end="")
        for cat in self.categories:
            print(f"{cat[:10]:<12}", end="")
        print()
        
        for i, cat in enumerate(self.categories):
            print(f"{cat[:14]:<15}", end="")
            for j in range(len(self.categories)):
                print(f"{cm[i][j]:<12}", end="")
            print()
        
        print("\n" + "="*80)
    
    def save_evaluation_results(self, filepath: str, metrics: Dict[str, Any] = None):
        """
        Save evaluation results to JSON file.
        
        Args:
            filepath: Path to save JSON file
            metrics: Evaluation metrics (uses self.evaluation_metrics if None)
        """
        if metrics is None:
            metrics = self.evaluation_metrics
        
        if not metrics:
            print("No metrics to save.")
            return
        
        with open(filepath, 'w') as f:
            json.dump(metrics, f, indent=2)
        
        print(f"Evaluation results saved to {filepath}")


def load_receipts_from_firestore(user_id: str = None, limit: int = 100) -> List[Dict]:
    """
    Load receipts from Firestore (mock implementation - replace with actual Firestore connection).
    
    Args:
        user_id: Optional user ID to filter receipts
        limit: Maximum number of receipts to load
        
    Returns:
        List of receipt dictionaries
    """
    # This is a placeholder - replace with actual Firestore connection
    # from google.cloud import firestore
    # db = firestore.Client()
    # receipts_ref = db.collection("receipts_parsed")
    # if user_id:
    #     receipts_ref = receipts_ref.where("userId", "==", user_id)
    # receipts = receipts_ref.limit(limit).stream()
    # return [doc.to_dict() for doc in receipts]
    
    # Mock data for demonstration
    return [
        {
            'receiptId': f'receipt_{i}',
            'parsedData': {
                'raw': {
                    'vendor': 'Grocery Store',
                    'total': 150.50,
                    'items': [
                        {'name': 'Milk', 'price': 50},
                        {'name': 'Bread', 'price': 30},
                        {'name': 'Eggs', 'price': 70.50}
                    ]
                }
            },
            'categories': ['groceries'],
            'vendor': 'Grocery Store',
            'timestamp': datetime.utcnow().isoformat()
        }
        for i in range(10)
    ]


def main():
    """
    Main function to demonstrate Gemini retraining and evaluation.
    """
    print("="*80)
    print("Gemini Model Retraining for PocketSage Receipt Categorization")
    print("="*80)
    
    # Initialize trainer
    trainer = GeminiReceiptTrainer(model_name="gemini-2.0-flash")
    
    # Load training and test data
    print("\nLoading receipt data...")
    all_receipts = load_receipts_from_firestore(limit=100)
    
    # Prepare training data
    training_examples = trainer.prepare_training_data(all_receipts)
    print(f"Prepared {len(training_examples)} training examples")
    
    if len(training_examples) < 2:
        print("Error: Need at least 2 training examples. Using mock data...")
        # Add more mock data for demonstration
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
            }
        ]
    
    # Split into training and test sets (80/20)
    split_idx = int(len(training_examples) * 0.8)
    train_set = training_examples[:split_idx]
    test_set = training_examples[split_idx:]
    
    if len(test_set) == 0:
        # If no test set, use training set for demonstration
        test_set = train_set[:min(5, len(train_set))]
    
    print(f"Training set: {len(train_set)} examples")
    print(f"Test set: {len(test_set)} examples")
    
    # Evaluate with few-shot learning
    print("\nEvaluating model with few-shot learning...")
    metrics_few_shot = trainer.evaluate_model(
        training_data=train_set,
        test_data=test_set,
        use_few_shot=True
    )
    
    trainer.print_evaluation_report(metrics_few_shot)
    
    # Save results
    results_file = f"gemini_evaluation_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    trainer.save_evaluation_results(results_file, metrics_few_shot)
    
    print("\n" + "="*80)
    print("Retraining and evaluation complete!")
    print("="*80)


if __name__ == "__main__":
    main()

