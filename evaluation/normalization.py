"""
Normalization Script for PocketSage Receipt Categorization
Comprehensive preprocessing pipeline for receipt and transaction data.
"""

import re
import json
from typing import Dict, List, Any, Optional
from datetime import datetime


class ReceiptNormalizer:
    """
    Comprehensive normalization engine for receipt and transaction data.
    Handles abbreviation expansion, noise removal, OCR correction, and language normalization.
    """
    
    def __init__(self):
        # Abbreviation mappings for common merchants and terms
        self.abbreviation_map = {
            # Indian merchants
            'DMART': 'D-Mart',
            'DMART': 'D-Mart',
            'BLR METRO': 'Bangalore Metro',
            'BLR': 'Bangalore',
            'MCD': "McDonald's",
            'KFC': 'KFC',
            'DOM': "Domino's",
            'PIZZA HUT': 'Pizza Hut',
            'SWIGGY': 'Swiggy',
            'ZOMATO': 'Zomato',
            'UBER': 'Uber',
            'OLA': 'Ola',
            'AMZN': 'Amazon',
            'FLIPKART': 'Flipkart',
            'BIGBASKET': 'BigBasket',
            'GROFERS': 'Grofers',
            
            # Common abbreviations
            'LTD': 'Limited',
            'PVT': 'Private',
            'INC': 'Incorporated',
            'CORP': 'Corporation',
            'CO': 'Company',
            'ST': 'Street',
            'RD': 'Road',
            'AVE': 'Avenue',
            'BLVD': 'Boulevard',
            
            # Payment methods
            'UPI': 'UPI',
            'NEFT': 'NEFT',
            'RTGS': 'RTGS',
            'IMPS': 'IMPS',
            'CARD': 'Card',
            'CASH': 'Cash',
            
            # Common item abbreviations
            'QTY': 'Quantity',
            'QTY': 'Qty',
            'PCS': 'Pieces',
            'KG': 'Kilogram',
            'GM': 'Gram',
            'LTR': 'Liter',
            'ML': 'Milliliter',
        }
        
        # Common OCR error patterns and corrections
        self.ocr_corrections = {
            # Number confusions
            r'0(?=[A-Za-z])': 'O',  # 0 -> O before letters
            r'1(?=[A-Za-z])': 'I',  # 1 -> I before letters
            r'5(?=[A-Za-z])': 'S',  # 5 -> S before letters
            r'8(?=[A-Za-z])': 'B',  # 8 -> B before letters
            
            # Common character confusions
            r'rn': 'm',  # rn -> m
            r'vv': 'w',  # vv -> w
            r'cl': 'd',  # cl -> d
        }
        
        # Noise patterns to remove
        self.noise_patterns = [
            r'Transaction ID:?\s*\w+',
            r'Ref No:?\s*\w+',
            r'Reference:?\s*\w+',
            r'TXN ID:?\s*\w+',
            r'Order ID:?\s*\w+',
            r'Invoice No:?\s*\w+',
            r'Bill No:?\s*\w+',
            r'Receipt No:?\s*\w+',
            r'Time:?\s*\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AP]M)?',
            r'Date:?\s*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}',
            r'\b\d{10,}\b',  # Long numeric strings (likely IDs)
            r'[^\w\s]+',  # Excessive punctuation (keep basic punctuation)
        ]
        
        # Language-specific normalization rules
        self.language_normalizations = {
            'hindi': {
                'रुपये': 'Rupees',
                '₹': 'Rupees',
            },
            'tamil': {
                'ரூபாய்': 'Rupees',
            },
            'telugu': {
                'రూపాయలు': 'Rupees',
            },
            'kannada': {
                'ರೂಪಾಯಿ': 'Rupees',
            },
        }
    
    def normalize_text(self, text: str) -> str:
        """
        Main normalization function that applies all preprocessing steps.
        
        Args:
            text: Raw text input
            
        Returns:
            Normalized text
        """
        if not text or not isinstance(text, str):
            return ""
        
        # Step 1: Convert to uppercase for consistent processing
        normalized = text.upper()
        
        # Step 2: Expand abbreviations
        normalized = self._expand_abbreviations(normalized)
        
        # Step 3: Remove noise
        normalized = self._remove_noise(normalized)
        
        # Step 4: Correct OCR errors
        normalized = self._correct_ocr_errors(normalized)
        
        # Step 5: Language normalization
        normalized = self._normalize_language(normalized)
        
        # Step 6: Clean whitespace
        normalized = self._clean_whitespace(normalized)
        
        return normalized
    
    def _expand_abbreviations(self, text: str) -> str:
        """Expand common abbreviations."""
        normalized = text
        for abbrev, expansion in self.abbreviation_map.items():
            # Case-insensitive replacement with word boundaries
            pattern = r'\b' + re.escape(abbrev) + r'\b'
            normalized = re.sub(pattern, expansion, normalized, flags=re.IGNORECASE)
        return normalized
    
    def _remove_noise(self, text: str) -> str:
        """Remove transaction IDs, timestamps, and other noise."""
        normalized = text
        for pattern in self.noise_patterns[:-1]:  # Exclude last pattern (punctuation)
            normalized = re.sub(pattern, '', normalized, flags=re.IGNORECASE)
        
        # Remove excessive punctuation but keep basic ones
        normalized = re.sub(r'[^\w\s.,!?]', '', normalized)
        
        return normalized
    
    def _correct_ocr_errors(self, text: str) -> str:
        """Correct common OCR errors."""
        normalized = text
        for pattern, replacement in self.ocr_corrections.items():
            normalized = re.sub(pattern, replacement, normalized)
        return normalized
    
    def _normalize_language(self, text: str) -> str:
        """Normalize language-specific terms."""
        normalized = text
        for lang, mappings in self.language_normalizations.items():
            for term, replacement in mappings.items():
                normalized = normalized.replace(term, replacement)
        return normalized
    
    def _clean_whitespace(self, text: str) -> str:
        """Clean up excessive whitespace."""
        # Replace multiple spaces with single space
        normalized = re.sub(r'\s+', ' ', text)
        # Remove leading/trailing whitespace
        normalized = normalized.strip()
        return normalized
    
    def normalize_receipt(self, receipt: Dict[str, Any]) -> Dict[str, Any]:
        """
        Normalize a complete receipt dictionary.
        
        Args:
            receipt: Receipt dictionary with various possible formats
            
        Returns:
            Normalized receipt dictionary
        """
        normalized = {
            'merchant': None,
            'items': [],
            'total': 0.0,
            'date': None,
            'payment_method': None,
            'normalized_text': '',
        }
        
        # Extract and normalize merchant name
        merchant_fields = ['merchant', 'merchant_name', 'vendor', 'vendor_name', 'store_name', 'shop_name']
        for field in merchant_fields:
            if field in receipt and receipt[field]:
                normalized['merchant'] = self.normalize_text(str(receipt[field]))
                break
        
        # Normalize items
        items_fields = ['items', 'receipt_items', 'line_items', 'products']
        for field in items_fields:
            if field in receipt and isinstance(receipt[field], list):
                for item in receipt[field]:
                    if isinstance(item, dict):
                        normalized_item = {
                            'name': self.normalize_text(str(item.get('name', item.get('item_name', '')))),
                            'price': float(item.get('price', item.get('unit_price', item.get('total_price', 0)))),
                            'quantity': item.get('quantity', item.get('qty', 1)),
                        }
                        normalized['items'].append(normalized_item)
                    elif isinstance(item, str):
                        normalized['items'].append({
                            'name': self.normalize_text(item),
                            'price': 0.0,
                            'quantity': 1,
                        })
                break
        
        # Normalize total amount
        total_fields = ['total', 'total_amount', 'total_price', 'amount', 'bill_total']
        for field in total_fields:
            if field in receipt:
                try:
                    value = receipt[field]
                    if isinstance(value, str):
                        # Extract numeric value from string
                        numbers = re.findall(r'\d+\.?\d*', value)
                        if numbers:
                            normalized['total'] = float(numbers[0])
                    else:
                        normalized['total'] = float(value)
                    break
                except (ValueError, TypeError):
                    continue
        
        # Extract date
        date_fields = ['date', 'receipt_date', 'transaction_date', 'purchase_date']
        for field in date_fields:
            if field in receipt:
                normalized['date'] = receipt[field]
                break
        
        # Extract payment method
        payment_fields = ['payment_method', 'payment_mode', 'payment_type']
        for field in payment_fields:
            if field in receipt:
                normalized['payment_method'] = self.normalize_text(str(receipt[field]))
                break
        
        # Create normalized text representation for categorization
        text_parts = []
        if normalized['merchant']:
            text_parts.append(f"Merchant: {normalized['merchant']}")
        if normalized['items']:
            item_names = [item['name'] for item in normalized['items'][:10]]
            text_parts.append(f"Items: {', '.join(item_names)}")
        if normalized['total'] > 0:
            text_parts.append(f"Total: {normalized['total']}")
        
        normalized['normalized_text'] = ' | '.join(text_parts)
        
        return normalized
    
    def normalize_batch(self, receipts: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Normalize a batch of receipts.
        
        Args:
            receipts: List of receipt dictionaries
            
        Returns:
            List of normalized receipt dictionaries
        """
        return [self.normalize_receipt(receipt) for receipt in receipts]
    
    def get_normalization_stats(self, original: str, normalized: str) -> Dict[str, Any]:
        """
        Get statistics about the normalization process.
        
        Args:
            original: Original text
            normalized: Normalized text
            
        Returns:
            Dictionary with normalization statistics
        """
        return {
            'original_length': len(original),
            'normalized_length': len(normalized),
            'length_change': len(normalized) - len(original),
            'abbreviations_expanded': sum(1 for abbrev in self.abbreviation_map.keys() if abbrev in original.upper()),
            'noise_removed': len(original) - len(normalized) if len(original) > len(normalized) else 0,
        }


# Example usage and testing
if __name__ == "__main__":
    normalizer = ReceiptNormalizer()
    
    # Test cases
    test_cases = [
        "DMART BLR METRO TRANSACTION ID: 1234567890",
        "MCD RESTAURANT Ref No: ABC123 Time: 12:30 PM",
        "SWIGGY ORDER ID: 9876543210",
        "₹500.00 रुपये Payment via UPI",
    ]
    
    print("=" * 80)
    print("NORMALIZATION TEST RESULTS")
    print("=" * 80)
    
    for i, test in enumerate(test_cases, 1):
        normalized = normalizer.normalize_text(test)
        stats = normalizer.get_normalization_stats(test, normalized)
        
        print(f"\nTest {i}:")
        print(f"  Original:  {test}")
        print(f"  Normalized: {normalized}")
        print(f"  Stats: {stats}")
    
    # Test receipt normalization
    print("\n" + "=" * 80)
    print("RECEIPT NORMALIZATION TEST")
    print("=" * 80)
    
    test_receipt = {
        'merchant_name': 'DMART',
        'items': [
            {'name': 'MILK 2%', 'price': 50.0},
            {'name': 'BRD LOAF', 'price': 30.0},
        ],
        'total_amount': '₹150.50',
        'transaction_id': 'TXN1234567890',
    }
    
    normalized_receipt = normalizer.normalize_receipt(test_receipt)
    print(f"\nOriginal Receipt: {json.dumps(test_receipt, indent=2)}")
    print(f"\nNormalized Receipt: {json.dumps(normalized_receipt, indent=2)}")

