import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
from typing import Optional, List
from datetime import datetime

class EmailService:
    def __init__(self):
        # Email configuration from environment variables
        self.smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.sender_email = os.getenv("SENDER_EMAIL")
        self.sender_password = os.getenv("SENDER_PASSWORD")
        self.app_name = os.getenv("APP_NAME", "PocketSage")
        
        if not self.sender_email or not self.sender_password:
            raise ValueError("SENDER_EMAIL and SENDER_PASSWORD environment variables must be set")
    
    def send_email(self, 
                   to_email: str, 
                   subject: str, 
                   body: str, 
                   html_body: Optional[str] = None,
                   attachments: Optional[List[str]] = None) -> bool:
        """
        Send an email to the specified recipient
        
        Args:
            to_email: Recipient email address
            subject: Email subject
            body: Plain text email body
            html_body: HTML email body (optional)
            attachments: List of file paths to attach (optional)
            
        Returns:
            bool: True if email sent successfully, False otherwise
        """
        try:
            # Create message
            msg = MIMEMultipart('alternative')
            msg['From'] = self.sender_email
            msg['To'] = to_email
            msg['Subject'] = subject
            
            # Add plain text body
            text_part = MIMEText(body, 'plain')
            msg.attach(text_part)
            
            # Add HTML body if provided
            if html_body:
                html_part = MIMEText(html_body, 'html')
                msg.attach(html_part)
            
            # Add attachments if provided
            if attachments:
                for file_path in attachments:
                    if os.path.exists(file_path):
                        with open(file_path, "rb") as attachment:
                            part = MIMEBase('application', 'octet-stream')
                            part.set_payload(attachment.read())
                        
                        encoders.encode_base64(part)
                        part.add_header(
                            'Content-Disposition',
                            f'attachment; filename= {os.path.basename(file_path)}'
                        )
                        msg.attach(part)
            
            # Send email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.sender_email, self.sender_password)
                server.send_message(msg)
            
            print(f"Email sent successfully to {to_email}")
            return True
            
        except Exception as e:
            print(f"Error sending email to {to_email}: {e}")
            return False
    
    def send_chatbot_message_email(self, 
                                  user_email: str, 
                                  user_name: str, 
                                  conversation_id: str,
                                  latest_message: str,
                                  conversation_summary: Optional[str] = None) -> bool:
        """
        Send the latest chatbot message via email
        
        Args:
            user_email: User's email address
            user_name: User's name
            conversation_id: Conversation ID
            latest_message: The latest chatbot message
            conversation_summary: Optional summary of the conversation
            
        Returns:
            bool: True if email sent successfully, False otherwise
        """
        subject = f"Your PocketSage Chatbot Response - {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        
        # Create HTML email body
        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>PocketSage Chatbot Response</title>
            <style>
                body {{
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                    background-color: #f4f4f4;
                }}
                .container {{
                    background-color: white;
                    padding: 30px;
                    border-radius: 10px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }}
                .header {{
                    text-align: center;
                    margin-bottom: 30px;
                    padding-bottom: 20px;
                    border-bottom: 2px solid #007bff;
                }}
                .logo {{
                    font-size: 24px;
                    font-weight: bold;
                    color: #007bff;
                    margin-bottom: 10px;
                }}
                .message-box {{
                    background-color: #f8f9fa;
                    border-left: 4px solid #007bff;
                    padding: 20px;
                    margin: 20px 0;
                    border-radius: 5px;
                }}
                .footer {{
                    margin-top: 30px;
                    padding-top: 20px;
                    border-top: 1px solid #eee;
                    text-align: center;
                    font-size: 12px;
                    color: #666;
                }}
                .conversation-id {{
                    background-color: #e9ecef;
                    padding: 10px;
                    border-radius: 5px;
                    font-family: monospace;
                    font-size: 12px;
                    margin: 10px 0;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div class="logo">🤖 PocketSage</div>
                    <p>Your AI Financial Assistant</p>
                </div>
                
                <h2>Hello {user_name},</h2>
                
                <p>Here's your latest chatbot response from PocketSage:</p>
                
                <div class="message-box">
                    <strong>Chatbot Response:</strong><br>
                    {latest_message.replace(chr(10), '<br>')}
                </div>
                
                <div class="conversation-id">
                    <strong>Conversation ID:</strong> {conversation_id}
                </div>
                
                {f'<p><strong>Conversation Summary:</strong><br>{conversation_summary}</p>' if conversation_summary else ''}
                
                <p>You can continue this conversation in the PocketSage app or reply to this email if you have any questions.</p>
                
                <div class="footer">
                    <p>This email was sent by PocketSage - Your Smart Financial Assistant</p>
                    <p>Sent on {datetime.now().strftime('%B %d, %Y at %I:%M %p')}</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        # Create plain text version
        text_body = f"""
        PocketSage - Your AI Financial Assistant
        
        Hello {user_name},
        
        Here's your latest chatbot response from PocketSage:
        
        {latest_message}
        
        Conversation ID: {conversation_id}
        
        {f'Conversation Summary: {conversation_summary}' if conversation_summary else ''}
        
        You can continue this conversation in the PocketSage app or reply to this email if you have any questions.
        
        Sent on {datetime.now().strftime('%B %d, %Y at %I:%M %p')}
        """
        
        return self.send_email(
            to_email=user_email,
            subject=subject,
            body=text_body,
            html_body=html_body
        )