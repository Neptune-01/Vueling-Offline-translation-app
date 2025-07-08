#!/bin/bash

# Couleurs pour le output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
IP="localhost"
API_URL="http://$IP:8000/api/v1/translate"
ITERATIONS=50
LANGUAGES=("french" "english" "spanish" "german" "italian")
DELAY=0.1

# Textes à traduire avec leur langue source
declare -A TEXTS=(
    ["Hello world, how are you today?"]="english"
    ["Je suis très content d'être ici aujourd'hui!"]="french"
    ["Das Wetter ist heute sehr schön."]="german"
    ["Mi piace molto mangiare la pizza italiana."]="italian"
    ["¿Dónde está la biblioteca?"]="spanish"
    ["The quick brown fox jumps over the lazy dog"]="english"
    ["L'été sera chaud cette année, préparez-vous!"]="french"
    ["Ich möchte ein Bier trinken, bitte."]="german"
    ["La vita è bella quando il sole splende."]="italian"
    ["El tiempo es oro, aprovéchalo bien."]="spanish"
)

# Compteurs
total_requests=0
successful_requests=0
failed_requests=0

# Fonction pour faire une requête
make_request() {
    local text="$1"
    local source="$2"
    local target="$3"
    local response
    
    response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"$text\", 
            \"target_language\": \"$target\", 
            \"source_language\": \"$source\"
        }")
    
    if [[ $response == *"translation"* ]]; then
        # Extraire la traduction du JSON
        translation=$(echo $response | jq -r '.translation')
        echo -e "${GREEN}✓${NC} Translation Details:"
        echo -e "${BLUE}Source Text${NC} ($source): $text"
        echo -e "${PURPLE}Target Lang${NC}: $target"
        echo -e "${CYAN}Translation${NC}: $translation"
        echo -e "----------------------------------------"
        return 0
    else
        echo -e "${RED}✗ Error in translation:${NC}"
        echo -e "${RED}Source Text${NC} ($source): $text"
        echo -e "${RED}Target Lang${NC}: $target"
        echo -e "${RED}Error${NC}: $response"
        echo -e "----------------------------------------"
        return 1
    fi
}

# Fonction pour afficher la progression
show_progress() {
    local success_rate=$(( (successful_requests * 100) / total_requests ))
    echo -e "\n${YELLOW}=== Test Progress ===${NC}"
    echo -e "Total requests: ${BLUE}$total_requests${NC}"
    echo -e "Successful: ${GREEN}$successful_requests${NC}"
    echo -e "Failed: ${RED}$failed_requests${NC}"
    echo -e "Success rate: ${PURPLE}${success_rate}%${NC}"
    echo -e "${YELLOW}==========================================${NC}\n"
}

# Vérification de dépendances
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed. Please install it first.${NC}"
        echo "On Fedora: sudo dnf install jq"
        echo "On Ubuntu: sudo apt install jq"
        exit 1
    fi
}

# Test de disponibilité de l'API
test_api_availability() {
    echo -e "${YELLOW}Testing API availability...${NC}"
    if ! curl -s "$API_URL" > /dev/null; then
        echo -e "${RED}API is not responding at $API_URL${NC}"
        exit 1
    fi
    echo -e "${GREEN}API is available. Starting stress test...${NC}"
}

# Fonction principale
main() {
    check_dependencies
    test_api_availability
    
    local total_combinations=$((${#TEXTS[@]} * ${#LANGUAGES[@]} * ITERATIONS))
    echo -e "Total combinations to test: ${BLUE}$total_combinations${NC}"
    
    # Boucle principale
    for ((i=1; i<=ITERATIONS; i++)); do
        echo -e "\n${YELLOW}=== Iteration $i ===${NC}"
        
        for text in "${!TEXTS[@]}"; do
            local source_lang="${TEXTS[$text]}"
            for target_lang in "${LANGUAGES[@]}"; do
                # Skip if source and target languages are the same
                if [[ "$source_lang" == "$target_lang" ]]; then
                    continue
                fi
                
                ((total_requests++))
                
                if make_request "$text" "$source_lang" "$target_lang"; then
                    ((successful_requests++))
                else
                    ((failed_requests++))
                fi
                
                sleep $DELAY
            done
        done
        
        show_progress
    done
    
    # Résultats finaux
    echo -e "\n${YELLOW}=== Final Results ===${NC}"
    echo -e "Total requests made: ${BLUE}$total_requests${NC}"
    echo -e "Successful requests: ${GREEN}$successful_requests${NC}"
    echo -e "Failed requests: ${RED}$failed_requests${NC}"
    echo -e "Success rate: ${PURPLE}$((successful_requests * 100 / total_requests))%${NC}"
    echo -e "Average requests per second: ${CYAN}$(bc <<< "scale=2; $total_requests / ($ITERATIONS * $DELAY)")${NC}"
    
    # Test de performance
    echo -e "\n${YELLOW}=== Performance Test ===${NC}"
    time for i in {1..10}; do
        curl -s -X POST "$API_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"Quick test\", \"target_language\": \"french\"}" > /dev/null
    done
}

# Exécution du script
main

exit 0
