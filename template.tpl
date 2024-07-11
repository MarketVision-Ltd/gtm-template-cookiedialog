const injectScript = require('injectScript');
const encodeUriComponent = require('encodeUriComponent');
const queryPermission = require('queryPermission');
const gtagSet = require('gtagSet');
const setDefaultConsentState = require('setDefaultConsentState');
const getCookieValues = require('getCookieValues');
const updateConsentState = require('updateConsentState');

const cookieDialogKey = data.licenseKey;
const consentModeEnabled = data.consentModeEnabled;
const language = data.language;
const waitForUpdate = data.waitForUpdate;
const urlPassthrough = data.urlPassthrough;
const adsDataRedaction = data.adsDataRedaction || 'dynamic';
const regionSettings = data.regionSettings || [];
let hasDefaultState = false;

if (consentModeEnabled !== false) {
	// string to array
    const getRegionArr = (regionStr) => {
        return regionStr.split(',')
            .map(region => region.trim())
            .filter(region => region.length !== 0);
    };

    // Get default consent state per region
    const getConsentRegionData = (regionObject) => {
        const consentRegionData = {
            ad_storage: regionObject.defaultConsentMarketing,
            ad_user_data: regionObject.defaultConsentMarketingAdUserData,
            ad_personalization: regionObject.defaultConsentMarketingAdPersonalization,
            analytics_storage: regionObject.defaultConsentStatistics,
            functionality_storage: regionObject.defaultConsentPreferences,
            personalization_storage: regionObject.defaultConsentPreferences,
            security_storage: 'granted'
        };
      
        const regionArr = getRegionArr(regionObject.region);
      
        if (regionArr.length) {
          consentRegionData.region = regionArr;
        }
        
        return consentRegionData;
    };
  
    // Set url_passthrough
    gtagSet({
      'url_passthrough': urlPassthrough === true
    });

    // Set default consent for each region
    regionSettings.forEach(regionObj => {
        const consentRegionData = getConsentRegionData(regionObj);

        if (waitForUpdate > 0) {
            consentRegionData.wait_for_update = waitForUpdate;
        }

        setDefaultConsentState(consentRegionData);
      
        if (regionObj.region === undefined || regionObj.region.trim() === '')
        {
          hasDefaultState = true;
        }
    });
  
    // Fallback to opt-out if no global default consent state has been defined in region settings
    if(!hasDefaultState) {
      setDefaultConsentState({
        ad_storage: 'denied',
        ad_user_data: 'denied',
        ad_personalization: 'denied',
        analytics_storage: 'denied',
        functionality_storage: 'denied',
        personalization_storage: 'denied',
        security_storage: 'granted'
      });
    }

    // Read existing consent from consent cookie if it exists
    let consentObj = null;
    
    if (getCookieValues("CookieConsent").toString() !== '') {
        const consentString = getCookieValues("CookieConsent")[0];

        if ((typeof consentString !== 'undefined') && (consentString.indexOf("{") === 0) && (consentString.indexOf("}") > 0)) {
            // Turn consentString into object
            consentObj = {
                preferences: 'denied',
                statistics: 'denied',
                marketing: 'denied',
                readConsentString: function (str) {
                    let tempA = str.replace('{', '').replace('}', '').split(","),
                        tempB = {};
                    for (let i = 0; i < tempA.length; i += 1) {
                        let tempC = tempA[i].split(':');
                        tempB[tempC[0]] = tempC[1];
                    }

                    consentObj.preferences = tempB.preferences === 'true' ? 'granted' : 'denied';
                    consentObj.statistics = tempB.statistics === 'true' ? 'granted' : 'denied';
                    consentObj.marketing = tempB.marketing === 'true' ? 'granted' : 'denied';
                    consentObj.region = tempB.region; // This is the region wherefrom the consent was originally submitted
                }
            };

            consentObj.readConsentString(consentString);

            updateConsentState({
                'ad_storage': consentObj.marketing,
                'ad_user_data': consentObj.marketing,
                'ad_personalization': consentObj.marketing,
                'analytics_storage': consentObj.statistics,
                'functionality_storage': consentObj.preferences,
                'personalization_storage': consentObj.preferences,
                'security_storage': 'granted'
            });
        }
    }
    
    // Set data redaction
    const marketingConsent = consentObj ? consentObj.marketing : 'denied';
    const marketingConsentBoolean = marketingConsent === 'granted';
    const adsDataRedactionValue = adsDataRedaction === 'dynamic' ? !marketingConsentBoolean : adsDataRedaction === 'true';
    
    gtagSet({
      'ads_data_redaction': adsDataRedactionValue
    });
}

let scriptUrl='https://cookie.marketvision.ch/consent.js?id='+encodeUriComponent(cookieDialogKey)+'&implementation=gtm';

if(consentModeEnabled === false){
  scriptUrl+='&consentmode=disabled';
}else{
  scriptUrl+='&consentmode-dataredaction='+adsDataRedaction;
}

if(language==='variable'){
  scriptUrl+='&lang='+encodeUriComponent(data.languageVariable);
}

if(queryPermission('inject_script', scriptUrl)){
  injectScript(scriptUrl,data.gtmOnSuccess,data.gtmOnFailure);
}else{
  data.gtmOnFailure();
}
