#!/bin/bash

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_VERSION="1.5.0"
AWS_CLI_VERSION="2"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Terraform Infrastructure Setup${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to print messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install Terraform >= ${TERRAFORM_VERSION}"
        exit 1
    fi
    
    TERRAFORM_INSTALLED=$(terraform version | head -1 | grep -oP 'Terraform v\K[0-9.]+')
    print_success "Terraform ${TERRAFORM_INSTALLED} found"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install AWS CLI v${AWS_CLI_VERSION}"
        exit 1
    fi
    
    AWS_INSTALLED=$(aws --version | grep -oP 'aws-cli/\K[0-9.]+')
    print_success "AWS CLI ${AWS_INSTALLED} found"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl not found. EKS operations will not be available until installed"
    else
        KUBECTL_VERSION=$(kubectl version --client --short | grep -oP 'v\K[0-9.]+')
        print_success "kubectl ${KUBECTL_VERSION} found"
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        print_warning "Helm not found. Helm chart deployments will not be available until installed"
    else
        HELM_VERSION=$(helm version --short | grep -oP 'v\K[0-9.]+')
        print_success "Helm ${HELM_VERSION} found"
    fi
}

# Check AWS credentials
check_aws_credentials() {
    print_info "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    
    print_success "AWS credentials verified"
    print_info "Account ID: ${ACCOUNT_ID}"
    print_info "User/Role: ${USER_ARN}"
}

# Check Terraform files
check_terraform_files() {
    print_info "Checking Terraform configuration files..."
    
    REQUIRED_FILES=(
        "main.tf"
        "variables.tf"
        "outputs.tf"
        "versions.tf"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Missing required file: $file"
            exit 1
        fi
        print_success "Found $file"
    done
    
    # Check modules directory
    if [ ! -d "modules" ]; then
        print_error "Missing modules directory"
        exit 1
    fi
    print_success "Found modules directory"
}

# Initialize Terraform
init_terraform() {
    print_info "Initializing Terraform..."
    
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found"
        print_info "Creating terraform.tfvars from example..."
        
        if [ -f "terraform.tfvars.example" ]; then
            cp terraform.tfvars.example terraform.tfvars
            print_success "Created terraform.tfvars"
            print_warning "Please edit terraform.tfvars with your actual values"
            return 1
        else
            print_error "terraform.tfvars.example not found"
            exit 1
        fi
    fi
    
    # Validate Terraform configuration
    print_info "Validating Terraform configuration..."
    if ! terraform validate; then
        print_error "Terraform validation failed"
        exit 1
    fi
    print_success "Terraform validation passed"
    
    # Initialize Terraform
    print_info "Running terraform init..."
    if terraform init; then
        print_success "Terraform initialized successfully"
    else
        print_error "Terraform init failed"
        exit 1
    fi
}

# Run linting and security checks
run_checks() {
    print_info "Running code quality checks..."
    
    # Format check
    print_info "Checking Terraform formatting..."
    if terraform fmt -check -recursive . > /dev/null 2>&1; then
        print_success "Formatting check passed"
    else
        print_warning "Formatting issues detected. Run 'terraform fmt -recursive' to fix"
    fi
    
    # TFLint check (if installed)
    if command -v tflint &> /dev/null; then
        print_info "Running TFLint..."
        if tflint . --init &> /dev/null; then
            if tflint . 2> /dev/null; then
                print_success "TFLint passed"
            else
                print_warning "TFLint found issues. Review above"
            fi
        fi
    fi
    
    # Checkov check (if installed)
    if command -v checkov &> /dev/null; then
        print_info "Running Checkov security scan..."
        if checkov -d . --framework terraform --quiet &> /dev/null; then
            print_success "Checkov security scan passed"
        else
            print_warning "Checkov found security issues. Review above"
        fi
    fi
}

# Generate plan
generate_plan() {
    print_info "Generating Terraform plan..."
    
    if terraform plan -out=tfplan -var-file=terraform.tfvars; then
        print_success "Terraform plan generated successfully"
        print_info "Plan saved to tfplan"
        print_info "Review the plan carefully before applying"
    else
        print_error "Terraform plan failed"
        exit 1
    fi
}

# Display summary
display_summary() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Setup Complete!${NC}"
    echo -e "${BLUE}========================================${NC}\n"
    
    print_success "Terraform is ready for deployment"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Review terraform.tfvars and ensure all values are correct"
    echo "2. Review the generated plan with: terraform show tfplan"
    echo "3. Apply the configuration with: terraform apply tfplan"
    echo ""
    echo -e "${YELLOW}Useful Commands:${NC}"
    echo "  terraform plan          - Generate new plan"
    echo "  terraform apply tfplan  - Apply configuration"
    echo "  terraform destroy       - Destroy infrastructure"
    echo "  terraform output        - Display outputs"
    echo "  terraform state list    - List resources in state"
    echo "  terraform fmt -r        - Format code"
    echo ""
}

# Main execution
main() {
    print_info "Starting Terraform setup process..."
    echo ""
    
    check_prerequisites
    echo ""
    
    check_aws_credentials
    echo ""
    
    check_terraform_files
    echo ""
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        init_terraform
        exit 1
    fi
    
    init_terraform
    echo ""
    
    run_checks
    echo ""
    
    read -p "Generate Terraform plan now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        generate_plan
        echo ""
    fi
    
    display_summary
}

# Run main function
main
