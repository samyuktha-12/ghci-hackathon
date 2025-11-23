import os
from GoogleWalletPassGenerator.eventticket import EventTicketManager
from GoogleWalletPassGenerator.types import (
    TranslatedString, LocalizedString, EventTicketClass, EventTicketClassId,
    EventTicketObject, EventTicketObjectId, Barcode, ObjectsToAddToWallet, EventTicketIdentifier
)
from GoogleWalletPassGenerator.enums import ReviewStatus, State, BarcodeType, BarcodeRenderEncoding
from GoogleWalletPassGenerator.serializer import serialize_to_json

def create_wallet_pass(
    class_id: str,
    object_id: str,
    event_name: str,
    barcode_value: str,
    issuer_name: str = "PocketSage"
):
    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", None)
    if not service_account_json:
        raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON environment variable must be set to the path of your Firebase service account JSON file")
    manager = EventTicketManager(service_account_json)
    issuerId = os.getenv("GOOGLE_WALLET_ISSUER_ID", None)
    if not issuerId:
        raise ValueError("GOOGLE_WALLET_ISSUER_ID environment variable must be set")

    eventTicketClass = serialize_to_json(
        EventTicketClass(
            id=EventTicketClassId(issuerId=issuerId, uniqueId=class_id),
            issuerName=issuer_name,
            eventName=LocalizedString(defaultValue=TranslatedString("en-US", event_name)),
            reviewStatus=ReviewStatus.UNDER_REVIEW,
        )
    )
    manager.create_class(eventTicketClass)

    eventTicketObject = serialize_to_json(
        EventTicketObject(
            id=EventTicketObjectId(issuerId=issuerId, uniqueId=object_id),
            classId=EventTicketClassId(issuerId=issuerId, uniqueId=class_id),
            state=State.ACTIVE,
            barcode=Barcode(
                type=BarcodeType.QR_CODE,
                renderEncoding=BarcodeRenderEncoding.UTF_8,
                value=barcode_value,
            )
        )
    )
    manager.create_object(eventTicketObject)

    objectsToAdd = serialize_to_json(
        ObjectsToAddToWallet([
            EventTicketIdentifier(
                id=EventTicketObjectId(issuerId=issuerId, uniqueId=object_id),
                classId=EventTicketClassId(issuerId=issuerId, uniqueId=class_id),
            )
        ])
    )
    walletUrls = manager.create_add_event_ticket_urls(objectsToAdd)
    return walletUrls
