import requests
import json
import time

class Authenticate:

    token = None

    def get_token(self):
        signup_url = "http://localhost:8080/api/v1/authentication/user/register"
        signin_url = "http://localhost:8080/api/v1/authentication/user/login"
        
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }

        signup_payload = {
            "email": "test@example.com",
            "password": "Password123!",
            "firstName": "Test",
            "lastName": "User",
            "username": "testuser",
            "phoneNumber": "12345678903",
            "userType": "USER"
        }

        try:
            # Usiamo json= invece di data=json.dumps per pulizia
            r_signup = requests.post(signup_url, headers=headers, json=signup_payload)
        except Exception as e:
            print(f"--- [AUTH] Error: {e}")

        # ATTESA: Molto importante per MongoDB/Spring Boot
        # Diamo 2 secondi al sistema per salvare l'utente nel DB
        time.sleep(2)

        signin_payload = {
            "email": "test@example.com",
            "password": "Password123!"
        }

        try:
            signin_response = requests.post(signin_url, headers=headers, json=signin_payload)
            print(f"--- [AUTH] Login Status: {signin_response.status_code}")
            response_data = signin_response.json()
            
            # Controllo nidificato della risposta
            if 'response' in response_data and response_data['response'] and 'accessToken' in response_data['response']:
                self.token = str(response_data['response']['accessToken'])
            else:
                print(f"--- [AUTH] ERRORE: Token token not found. Response: {response_data}")
        except Exception as e:
            print(f"--- [AUTH] Error: {e}")

    def request(self, flow):
        # Evitiamo loop: non iniettare il token se stiamo chiamando gli endpoint di auth
        if "/api/v1/authentication/" in flow.request.path:
            return

        if self.token is None:
            self.get_token()
        
        if self.token:
            flow.request.headers["Authorization"] = "Bearer " + self.token

addons = [Authenticate()]