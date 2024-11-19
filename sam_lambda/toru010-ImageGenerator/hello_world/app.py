import base64
import os

import boto3
import json
import random


def lambda_handler(event, context):
    # Initialize AWS clients
    bedrock_client = boto3.client("bedrock-runtime", region_name="us-east-1")
    s3_client = boto3.client("s3")

    # Define the model ID and S3 bucket name
    model_id = "amazon.titan-image-generator-v1"
    bucket_name = os.getenv("S3_BUCKET")

    # Hardcoded prompt
    prompt = "Rainy day in Oslo, with a clown in the background."

    # Generate a random seed
    seed = random.randint(0, 2147483647)
    s3_image_path = f"010/titan_{seed}.png"

    # Build the Bedrock request
    native_request = {
        "taskType": "TEXT_IMAGE",
        "textToImageParams": {"text": prompt},
        "imageGenerationConfig": {
            "numberOfImages": 1,
            "quality": "standard",
            "cfgScale": 8.0,
            "height": 1024,
            "width": 1024,
            "seed": seed,
        }
    }

    try:
        # Invoke the Bedrock model
        response = bedrock_client.invoke_model(modelId=model_id, body=json.dumps(native_request))
        model_response = json.loads(response["body"].read())

        # Decode the Base64 image data
        base64_image_data = model_response["images"][0]
        image_data = base64.b64decode(base64_image_data)

        # Upload the image to S3
        s3_client.put_object(Bucket=bucket_name, Key=s3_image_path, Body=image_data)

        # Return success response
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Image generated and uploaded successfully",
                "s3_path": f"s3://{bucket_name}/{s3_image_path}"
            }),
        }
    except Exception as e:
        # Log and return the error
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
