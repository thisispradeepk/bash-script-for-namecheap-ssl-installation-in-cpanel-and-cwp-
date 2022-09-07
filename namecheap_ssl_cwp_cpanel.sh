#! /bin/bash

### Collecting input data ###
input_data(){
        api_user="alexpaul"
        client_ip="1.1.1.1"
        echo "Enter Domain name"
        read domain
        echo "Enter ApiKey"
        read api_key
        domain_availability=0
        panel=0
        TODAY=$(date +"%Y-%m-%d-%T")
        current_directory=`$expr pwd`
        rm -r $domain.csr $domain.keys $domain-encode.csr 
        rm -r $current_directory/$domain-cert
        rm -r $current_directory/$domain-bundle
}

### Finding which panel is running on the server ###
find_cwp_or_cpanel() {
        /scripts/list_users > /dev/null 2>&1
        cwp=$?
        cat /etc/trueuserdomains > /dev/null 2>&1
        cpanel=$?

        #### For CWP ####
        if [ $cwp -eq 0 ]
        then
                panel=1
                #### find home folder ####
                domain_length=`$expr echo $domain | wc -c`
                if [[ $( /scripts/list_users | grep $domain | awk '{print $2}' | wc -c ) -eq $domain_length ]]
                then
                    home_folder=$( /scripts/list_users | grep $domain | awk '{print $1}' )
                    domain_availability=1
                else
                    echo "There is No domain you entered, Please provide the correct one"
                    exit 0
                fi
        #### For Cpanel ####
        elif [ $cpanel -eq 0 ]
        then
                panel=2
                #### find home folder ###
                domain_length=`$expr echo $domain | wc -c`
                domain_length=$(( domain_length+1 ))
                if [[ $( cat /etc/trueuserdomains | grep $domain | awk '{print $1}' | wc -c ) -eq $domain_length ]]
                then
                    home_folder=$( cat /etc/trueuserdomains | grep $domain | awk '{print $2}' )
                    domain_availability=1
                else
                    echo "There is No domain you entered, Please provide the correct one"
                    exit 0
                fi
        else
                echo "There is no hosting panel on the server"
                exit 0

        fi

}


### function Calling ###
input_data
find_cwp_or_cpanel


if [ $domain_availability -eq 1 ]
then
  
        echo -e "\e[1;31mWe are going to Generate Certificate\e[0m\n"
        ### Generate Certificate ###
        openssl req -out $domain.csr -new -newkey rsa:2048 -nodes -keyout $domain.keys

        echo -e "\e[1;31mCertificate Generated successfully!\e[0m\n"
        sleep 3
        
        echo -e "\e[1;31mNext is to buy a PositiveSSL for 1 year, for that follow the below step\e[0m\n"
        ### Purchasing PositiveSSL for 1 year ###
        echo -e "\nPlease copy and run the below API in your chrome browser and save the \e[1;31mCertificateID\e[0m"
        echo -e "\e[1;31mhttps://api.namecheap.com/xml.response?ApiUser=${api_user}&ApiKey=${api_key}&UserName=${api_user}&Command=namecheap.ssl.create&ClientIp=${client_ip}&Years=1&Type=PositiveSSL\e[0m"
        
        echo "Please provide CertificateID From the API response"
        read certificate_id
        
        ### ssl validation  ###
        choose_ssl_validation(){
                ### Choose validation method ###
                mkdir /home/$home_folder/public_html/.well-known > /dev/null 2>&1
                mkdir /home/$home_folder/public_html/.well-known/pki-validation > /dev/null 2>&1                
                echo "EC5A42AB493753B14C2B60767C5335CF68B9D67518A3F7265A30037A6D961B64 comodoca.com 612054811f92b" > /home/$home_folder/public_html/.well-known/pki-validation/944BABD0142E3BB271BDE1864F61870B.txt
                chown -R $home_folder:$home_folder /home/$home_folder/public_html/.well-known
                
                http_status_code=`$expr curl -s --head http://$domain/.well-known/pki-validation/944BABD0142E3BB271BDE1864F61870B.txt| head -n 1 | awk '{print $2}'`
                
                if [ $http_status_code -eq 200 ]
                then  
                    validation_method=1
                    
                else
                    echo -e "The HTTP validation method is not working, please choose other methods\n"
                    echo -e "Enter '2' for dns based validation, \nor enter '3' for mail based validation"
                    read validation_method
                
                fi
                
                ### Decode domain csr ###
                echo -e "Please encode csr with the url \e[1;31m 'https://meyerweb.com/eric/tools/dencoder/' \e[0m\n"
                cat $domain.csr
                
                echo -e "Please enter the encoded csr"
                read csr_encoded
                echo $csr_encoded > $domain-encode.csr
                
                echo -e "\nPlease copy and run the below API in your chrome browser for activating the SSL"
                ### DNS based validation ###
                if [ $validation_method -eq 1 ]
                then
                    echo -e "\n\e[1;31mhttps://api.namecheap.com/xml.response?ApiUser=${api_user}&ApiKey=${api_key}&UserName=${api_user}&Command=namecheap.ssl.activate&ClientIp=${client_ip}&CertificateID=${certificate_id}&csr=${csr_encoded}&AdminEmailAddress=admin%40${domain}&HTTPDCValidation=TRUE\e[0m\n"
                    
                    echo -e "Please provide File name(.txt) From the API response "
                    read validation_file
                    echo -e "Also, provide the content of that file, which will also be get from the API response"
                    read validation_file_content
                    
                    touch /home/$home_folder/public_html/.well-known/pki-validation/$validation_file
                    echo $validation_file_content > /home/$home_folder/public_html/.well-known/pki-validation/$validation_file
                    chown -R $home_folder:$home_folder /home/$home_folder/public_html/.well-known

                    echo -e "http validation url : $domain/well-known/pki-validation/$validation_file"
                    
                    
                ### DNS based validation ###    
                elif [ $validation_method -eq 2 ]
                then
                    echo -e "\n\e[1;31mhttps://api.namecheap.com/xml.response?ApiUser=${api_user}&ApiKey=${api_key}&UserName=${api_user}&Command=namecheap.ssl.activate&ClientIp=${client_ip}&CertificateID=${certificate_id}&csr=${csr_encoded}&AdminEmailAddress=admin%40${domain}&DNSDCValidation=TRUE\e[0m\n"
                    
                    echo -e "\n\e[1;31m Please Add cname record in dns, you will get the record from the API response \e[0m\n"
                
                ### Mail based validation ###     
                elif [ $validation_method -eq 3 ]
                then
                    echo -e "\n\e[1;31mhttps://api.namecheap.com/xml.response?ApiUser=${api_user}&ApiKey=${api_key}&UserName=${api_user}&Command=namecheap.ssl.activate&ClientIp=${client_ip}&CertificateID=${certificate_id}&csr=${csr_encoded}&AdminEmailAddress=admin%40${domain}&ApproverEmail=admin@${domain}\e[0m\n"
                    
                    echo -e "\n\e[1;31m Please check admin@${domain} mail \e[0m\n"
                    
                else
                    echo "Wrong method is wrong"
                fi
                
        }

        choose_ssl_validation
        
        echo -e "\n\e[1;31m We assume you have downloaded CRT and CABUNDLE from Namecheap, if yes, please type 'downloaded' \e[0m\n"
        read downloaded
        
        ### Installation of SSL certificate###

        ### Installation of SSL certificate in CWP ###
        if [ $panel -eq 1 ]
        then
            mv /etc/pki/tls/certs/$domain.cert  /etc/pki/tls/certs/$domain-$TODAY.cert
            mv /etc/pki/tls/private/$domain.key  /etc/pki/tls/private/$domain-$TODAY.key
            mv /etc/pki/tls/certs/$domain.bundle  /etc/pki/tls/certs/$domain-$TODAY.bundle

            echo -e "\n Please copy Certificate: (CRT) in to file $current_directory/$domain-cert"
            echo -e "\n Please copy Certificate Authority Bundle: (CABUNDLE) in to file $current_directory/$domain-bundle"

            echo -e "\n After copying CRT and CABUNDLE, type 'copied' "
            read copied

            cp $current_directory/$domain-cert  /etc/pki/tls/certs/$domain.cert
            cp $current_directory/$domain-bundle  /etc/pki/tls/certs/$domain.bundle
            cp $domain.keys  /etc/pki/tls/private/$domain.key
            
            echo -e "Please check http conf and restart httpd, All done!"
            
        elif [ $panel -eq 2 ]
        then
            
            cp /var/cpanel/ssl/apache_tls/$domain/combined /root/$domain-$TODAY-combined
            > /var/cpanel/ssl/apache_tls/$domain/combined

            echo -e "\n Please copy Certificate: (CRT) in to file $current_directory/$domain-cert"
            echo -e "\n Please copy Certificate Authority Bundle: (CABUNDLE) in to file $current_directory/$domain-bundle"

            echo -e "\n After copying CRT and CABUNDLE, type 'copied' "
            read copied
            
            cat $current_directory/$domain-cert >> /var/cpanel/ssl/apache_tls/$domain/combined
            cat $domain.keys >> /var/cpanel/ssl/apache_tls/$domain/combined
            cat $current_directory/$domain-bundle >> /var/cpanel/ssl/apache_tls/$domain/combined
            
            echo -e "Please check http conf and restart httpd, All done!"
            
            
        else
            echo "No panel"
        fi

fi      




