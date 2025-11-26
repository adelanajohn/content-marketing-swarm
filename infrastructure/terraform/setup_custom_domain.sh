#!/bin/bash

# Custom Domain Setup Script for HTTPS ALB
# This script helps you set up a custom domain with Route 53 for HTTPS

set -e

echo "=========================================="
echo "Custom Domain Setup for HTTPS ALB"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed. Some features may not work.${NC}"
    echo "Install jq for better output: https://stedolan.github.io/jq/"
fi

echo "Step 1: Check for existing domains and hosted zones"
echo "---------------------------------------------------"

# Check for registered domains
echo "Checking for registered domains..."
DOMAINS=$(aws route53domains list-domains --region us-east-1 --output json 2>/dev/null || echo '{"Domains":[]}')
DOMAIN_COUNT=$(echo "$DOMAINS" | jq -r '.Domains | length')

if [ "$DOMAIN_COUNT" -gt 0 ]; then
    echo -e "${GREEN}Found $DOMAIN_COUNT registered domain(s):${NC}"
    echo "$DOMAINS" | jq -r '.Domains[] | "  - \(.DomainName)"'
else
    echo "No registered domains found in Route 53."
fi

echo ""

# Check for hosted zones
echo "Checking for hosted zones..."
ZONES=$(aws route53 list-hosted-zones --output json 2>/dev/null || echo '{"HostedZones":[]}')
ZONE_COUNT=$(echo "$ZONES" | jq -r '.HostedZones | length')

if [ "$ZONE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}Found $ZONE_COUNT hosted zone(s):${NC}"
    echo "$ZONES" | jq -r '.HostedZones[] | "  - \(.Name) (ID: \(.Id | split("/")[2]))"'
else
    echo "No hosted zones found."
fi

echo ""
echo "=========================================="
echo "Step 2: Domain Configuration"
echo "=========================================="
echo ""

# Ask user what they want to do
echo "What would you like to do?"
echo "1) Use an existing domain/hosted zone"
echo "2) Register a new domain via Route 53"
echo "3) Create hosted zone for external domain"
echo "4) Exit and do this manually"
echo ""
read -p "Enter your choice (1-4): " CHOICE

case $CHOICE in
    1)
        echo ""
        echo "Using existing domain/hosted zone"
        echo "---------------------------------"
        
        if [ "$ZONE_COUNT" -eq 0 ]; then
            echo -e "${RED}Error: No hosted zones found. Please create one first.${NC}"
            exit 1
        fi
        
        # List hosted zones
        echo "Available hosted zones:"
        echo "$ZONES" | jq -r '.HostedZones[] | "\(.Id | split("/")[2]): \(.Name)"' | nl
        
        echo ""
        read -p "Enter the hosted zone ID (e.g., Z1234567890ABC): " HOSTED_ZONE_ID
        
        # Get zone details
        ZONE_NAME=$(aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" | jq -r '.HostedZone.Name' | sed 's/\.$//')
        
        echo ""
        read -p "Enter subdomain for API (e.g., api): " SUBDOMAIN
        DOMAIN_NAME="${SUBDOMAIN}.${ZONE_NAME}"
        ;;
        
    2)
        echo ""
        echo "Register new domain via Route 53"
        echo "---------------------------------"
        echo -e "${YELLOW}Note: Domain registration requires payment and can take up to 3 days.${NC}"
        echo "Please register domain via AWS Console:"
        echo "https://console.aws.amazon.com/route53/home#DomainRegistration:"
        echo ""
        echo "After registration, run this script again and choose option 1."
        exit 0
        ;;
        
    3)
        echo ""
        echo "Create hosted zone for external domain"
        echo "---------------------------------------"
        read -p "Enter your domain name (e.g., yourdomain.com): " DOMAIN_NAME_INPUT
        
        echo ""
        echo "Creating hosted zone for $DOMAIN_NAME_INPUT..."
        
        ZONE_OUTPUT=$(aws route53 create-hosted-zone \
            --name "$DOMAIN_NAME_INPUT" \
            --caller-reference "$(date +%s)" \
            --hosted-zone-config Comment="Hosted zone for content marketing swarm" \
            --output json)
        
        HOSTED_ZONE_ID=$(echo "$ZONE_OUTPUT" | jq -r '.HostedZone.Id' | cut -d'/' -f3)
        NAME_SERVERS=$(echo "$ZONE_OUTPUT" | jq -r '.DelegationSet.NameServers[]')
        
        echo -e "${GREEN}Hosted zone created successfully!${NC}"
        echo "Hosted Zone ID: $HOSTED_ZONE_ID"
        echo ""
        echo -e "${YELLOW}IMPORTANT: Update your domain registrar with these name servers:${NC}"
        echo "$NAME_SERVERS"
        echo ""
        echo "After updating name servers, wait 24-48 hours for DNS propagation."
        echo ""
        
        read -p "Enter subdomain for API (e.g., api): " SUBDOMAIN
        DOMAIN_NAME="${SUBDOMAIN}.${DOMAIN_NAME_INPUT}"
        ;;
        
    4)
        echo "Exiting. Please configure manually using the guide:"
        echo ".kiro/specs/https-alb-setup/CUSTOM_DOMAIN_SETUP_GUIDE.md"
        exit 0
        ;;
        
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Step 3: Update Terraform Configuration"
echo "=========================================="
echo ""

echo "Configuration Summary:"
echo "  Domain Name: $DOMAIN_NAME"
echo "  Hosted Zone ID: $HOSTED_ZONE_ID"
echo ""

# Update terraform.tfvars
TFVARS_FILE="environments/dev/terraform.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${RED}Error: $TFVARS_FILE not found${NC}"
    echo "Please run this script from the infrastructure/terraform directory"
    exit 1
fi

echo "Updating $TFVARS_FILE..."

# Check if domain variables already exist
if grep -q "domain_name" "$TFVARS_FILE"; then
    # Update existing
    sed -i.bak "s|domain_name.*=.*|domain_name     = \"$DOMAIN_NAME\"|" "$TFVARS_FILE"
    sed -i.bak "s|hosted_zone_id.*=.*|hosted_zone_id  = \"$HOSTED_ZONE_ID\"|" "$TFVARS_FILE"
else
    # Add new
    echo "" >> "$TFVARS_FILE"
    echo "# Custom domain configuration" >> "$TFVARS_FILE"
    echo "domain_name     = \"$DOMAIN_NAME\"" >> "$TFVARS_FILE"
    echo "hosted_zone_id  = \"$HOSTED_ZONE_ID\"" >> "$TFVARS_FILE"
fi

echo -e "${GREEN}Configuration updated successfully!${NC}"
echo ""

echo "=========================================="
echo "Step 4: Apply Terraform Changes"
echo "=========================================="
echo ""

read -p "Would you like to apply Terraform changes now? (y/n): " APPLY_NOW

if [ "$APPLY_NOW" = "y" ] || [ "$APPLY_NOW" = "Y" ]; then
    cd environments/dev
    
    echo ""
    echo "Running terraform plan..."
    terraform plan
    
    echo ""
    read -p "Does the plan look correct? Apply changes? (y/n): " CONFIRM_APPLY
    
    if [ "$CONFIRM_APPLY" = "y" ] || [ "$CONFIRM_APPLY" = "Y" ]; then
        echo ""
        echo "Applying Terraform changes..."
        echo "This may take 5-30 minutes for certificate validation..."
        terraform apply -auto-approve
        
        echo ""
        echo -e "${GREEN}Terraform apply completed!${NC}"
        echo ""
        
        # Get outputs
        echo "Terraform Outputs:"
        terraform output
        
        echo ""
        echo -e "${GREEN}Setup complete!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Verify certificate status: terraform output acm_certificate_status"
        echo "2. Test HTTPS endpoint: curl -v https://$DOMAIN_NAME/health"
        echo "3. Update frontend environment variables"
        echo "4. Rebuild and redeploy frontend"
        echo ""
        echo "See full guide: .kiro/specs/https-alb-setup/CUSTOM_DOMAIN_SETUP_GUIDE.md"
    else
        echo "Skipping apply. You can run 'terraform apply' manually later."
    fi
else
    echo ""
    echo "Skipping Terraform apply."
    echo "To apply changes manually:"
    echo "  cd environments/dev"
    echo "  terraform plan"
    echo "  terraform apply"
fi

echo ""
echo "=========================================="
echo "Setup script completed!"
echo "=========================================="
