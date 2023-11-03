param emailLogicAppName string = 'email-techsupport-integration'
@secure()
param openAIServiceKey string
param openAIUri string
param openAIDeploymentName string = 'gpt-35-turbo-16k'

resource office365Connection 'Microsoft.Web/connections@2016-06-01' = {
  // Fits the purpose for a hands-on lab
  #disable-next-line no-loc-expr-outside-params
  location: resourceGroup().location
  name: 'office365'
  //kind: 'V1'
  properties: {
    api: {
      // name: 'office365'
      // displayName: 'Office 365 Outlook'
      // description: 'Microsoft Office 365 is a cloud-based service that is designed to help meet your organization\'s needs for robust security, reliability, and user productivity.'
      // iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1626/1.0.1626.3238/office365/icon.png'
      // brandColor: '#0078D4'
      // type: 'Microsoft.Web/locations/managedApis'
      // Fits the purpose for a hands-on lab
      #disable-next-line no-loc-expr-outside-params
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', resourceGroup().location, 'office365')
    }
    displayName: 'Your Office 365 Account'
    // testLinks: [
    //   {
    //     requestUri: 'https://management.azure.com:443/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/connections/office365/extensions/proxy/testconnection?api-version=2016-06-01'
    //     method: 'get'
    //   }
    // ]
  }
}

resource conversionservice 'Microsoft.Web/connections@2016-06-01' = {
  // Fits the purpose for a hands-on lab
  #disable-next-line no-loc-expr-outside-params
  location: resourceGroup().location
  name: 'conversionservice'
  //kind: 'V1'
  properties: {
    api: {
      description: 'A service that allows content to be converted from one format to another.'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1625/1.0.1625.3226/conversionservice/icon.png'
      brandColor: '#4f6bed'
      type: 'Microsoft.Web/locations/managedApis'
      // Fits the purpose for a hands-on lab
      #disable-next-line no-loc-expr-outside-params
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', resourceGroup().location, 'conversionservice')
      //id: 'subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/conversionservice'
    }
    displayName: 'Content Conversion'
  }
}

resource requestOpenAIResponseLogicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: emailLogicAppName
  // Fits the purpose for a hands-on lab
  #disable-next-line no-loc-expr-outside-params
  location: resourceGroup().location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              properties: {
                emailto: {
                  type: 'string'
                }
                question: {
                  type: 'string'
                }
                subject: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
      }
      actions: {
        Condition: {
          actions: {
            'Send_an_email_(V2)': {
              runAfter: {}
              type: 'ApiConnection'
              inputs: {
                body: {
                  Body: '<p>Hello,<br>\n<br>\nThank you for reaching out to us. Support ticket No. 456454 has been created for you. We should contact you shortly</p>'
                  Importance: 'Normal'
                  Subject: 'Support ticket No. 456454 '
                  To: '@triggerBody()?[\'emailto\']'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
              }
            }
          }
          runAfter: {
            Send_email_with_options: [
              'Succeeded'
            ]
          }
          expression: {
            and: [
              {
                equals: [
                  '@body(\'Send_email_with_options\')?[\'SelectedOption\']'
                  'Not Useful'
                ]
              }
            ]
          }
          type: 'If'
        }
        For_each: {
          foreach: '@body(\'Parse_JSON\')?[\'choices\']'
          actions: {
            Append_to_string_variable: {
              runAfter: {}
              type: 'AppendToStringVariable'
              inputs: {
                name: 'finalanswer'
                value: '@item()?[\'message\'][\'content\']'
              }
            }
          }
          runAfter: {
            Parse_JSON: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        HTTP: {
          runAfter: {
            Initialize_variable: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            body: {
              max_tokens: 400
              messages: [
                {
                  content: '@variables(\'finalprompt\')'
                  role: 'user'
                }
              ]
              // Workaround per https://github.com/Azure/bicep/issues/1386
              temperature: json('0.2')
            }
            headers: {
              'Content-Type': 'application/json'
              'api-key': openAIServiceKey
            }
            method: 'POST'
            // When copied from the OpenAI Studio, the URI already contains an ending '/'
            uri: '${openAIUri}openai/deployments/${openAIDeploymentName}/chat/completions?api-version=2023-05-15'
          }
        }
        Initialize_emailTo: {
          inputs: {
            variables: [
              {
                name: 'emailto'
                type: 'string'
                value: '@triggerBody()?[\'emailto\']'
              }
            ]
          }
          runAfter: {
            Initialize_prompt: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
        }
        Initialize_final_prompt: {
          runAfter: {
            Initialize_question: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'finalprompt'
                type: 'string'
              }
            ]
          }
        }
        Initialize_prompt: {
          runAfter: {}
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'prompt'
                type: 'string'
                value: 'You are a Helpdesk assistant. Extract the person\'s name and technical problem from the text below. Provide possible solutions including link to websites in html. If no solutions are found, respond with \'We will get back to you in 48 hrs\'. \nIf this is a hardware problem give them tips for troubleshooting and indicate we will create a support ticket and schedule a repair within 48 hours.'
              }
            ]
          }
        }
        Initialize_question: {
          runAfter: {
            Initialize_emailTo: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'question'
                type: 'string'
                value: '@triggerBody()?[\'question\']'
              }
            ]
          }
        }
        Initialize_variable: {
          runAfter: {
            Set_variable: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'finalanswer'
                type: 'string'
              }
            ]
          }
        }
        Parse_JSON: {
          runAfter: {
            HTTP: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'HTTP\')'
            schema: {
              properties: {
                choices: {
                  items: {
                    properties: {
                      finish_reason: {
                        type: 'string'
                      }
                      index: {
                        type: 'integer'
                      }
                      message: {
                        content: {
                          type: 'string'
                        }
                      }
                    }
                    required: [
                      'message'
                      'index'
                      'finish_reason'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
                created: {
                  type: 'integer'
                }
                id: {
                  type: 'string'
                }
                model: {
                  type: 'string'
                }
                object: {
                  type: 'string'
                }
                usage: {
                  properties: {
                    completion_tokens: {
                      type: 'integer'
                    }
                    prompt_tokens: {
                      type: 'integer'
                    }
                    total_tokens: {
                      type: 'integer'
                    }
                  }
                  type: 'object'
                }
              }
              type: 'object'
            }
          }
        }
        Response: {
          runAfter: {
            Condition: [
              'Succeeded'
            ]
          }
          type: 'Response'
          kind: 'Http'
          inputs: {
            body: 'Done!'
            statusCode: 200
          }
        }
        Send_email_with_options: {
          runAfter: {
            For_each: [
              'Succeeded'
            ]
          }
          type: 'ApiConnectionWebhook'
          inputs: {
            body: {
              Message: {
                Body: '@variables(\'finalanswer\')'
                HideHTMLMessage: false
                Importance: 'Normal'
                Options: 'Useful, Not Useful'
                ShowHTMLConfirmationDialog: true
                Subject: 'Automated response from your Helpdesk AI bot'
                To: '@variables(\'emailto\')'
              }
              NotificationUrl: '@{listCallbackUrl()}'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            path: '/mailwithoptions/$subscriptions'
          }
        }
        Set_variable: {
          runAfter: {
            Initialize_final_prompt: [
              'Succeeded'
            ]
          }
          type: 'SetVariable'
          inputs: {
            name: 'finalprompt'
            value: '@{concat(variables(\'prompt\'),\' \',variables(\'question\'))}'
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          office365: {
            connectionId: office365Connection.id
            connectionName: 'office365'
            id: reference('Microsoft.Web/connections/office365', '2016-06-01').api.id
          }
        }
      }
    }
  }
}

param readMailboxLogicAppName string = 'read-mailbox-techsupport'

resource readSupportMailboxLogicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: readMailboxLogicAppName
  // Fits the purpose for a hands-on lab
  #disable-next-line no-loc-expr-outside-params
  location: resourceGroup().location
  properties: {
    state: 'Disabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        'When_a_new_email_arrives_(V3)': {
          inputs: {
            fetch: {
              method: 'get'
              pathTemplate: {
                template: '/v3/Mail/OnNewEmail'
              }
              queries: {
                fetchOnlyWithAttachment: false
                folderPath: 'Inbox'
                importance: 'Any'
                includeAttachments: false
                subjectFilter: 'Helpdesk bot'
              }
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            subscribe: {
              body: {
                NotificationUrl: '@{listCallbackUrl()}'
              }
              method: 'post'
              pathTemplate: {
                template: '/GraphMailSubscriptionPoke/$subscriptions'
              }
              queries: {
                fetchOnlyWithAttachment: false
                folderPath: 'Inbox'
                importance: 'Any'
              }
            }
          }
          splitOn: '@triggerBody()?[\'value\']'
          type: 'ApiConnectionNotification'
        }
      }
      actions: {
        Compose: {
          runAfter: {
            Set_variable_3: [
              'Succeeded'
            ]
          }
          type: 'Compose'
          inputs: {
            emailto: '@{variables(\'emailto\')}'
            question: '@{variables(\'question\')}'
            subject: '@{triggerBody()?[\'Subject\']}'
          }
        }
        Condition: {
          actions: {
            Html_to_text: {
              runAfter: {}
              type: 'ApiConnection'
              inputs: {
                body: '<p>@{triggerBody()?[\'Body\']}</p>'
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'conversionservice\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/html2text'
              }
            }
            Set_variable: {
              runAfter: {
                Html_to_text: [
                  'Succeeded'
                ]
              }
              type: 'SetVariable'
              inputs: {
                name: 'question'
                value: '@body(\'Html_to_text\')'
              }
            }
          }
          runAfter: {
            Initialize_variable_2: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Set_variable_2: {
                runAfter: {}
                type: 'SetVariable'
                inputs: {
                  name: 'question'
                  value: '@triggerBody()?[\'Body\']'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@triggerBody()?[\'IsHtml\']'
                  true
                ]
              }
            ]
          }
          type: 'If'
        }
        HTTP: {
          runAfter: {
            Compose: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            body: '@outputs(\'Compose\')'
            method: 'POST'
            uri: requestTrigger.listCallbackUrl().value
          }
        }
        Initialize_variable: {
          runAfter: {}
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'question'
                type: 'string'
              }
            ]
          }
        }
        Initialize_variable_2: {
          runAfter: {
            Initialize_variable: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'emailto'
                type: 'string'
              }
            ]
          }
        }
        Set_variable_3: {
          runAfter: {
            Condition: [
              'Succeeded'
            ]
          }
          type: 'SetVariable'
          inputs: {
            name: 'emailto'
            value: '@triggerBody()?[\'From\']'
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          conversionservice: {
            connectionId: conversionservice.id
            connectionName: 'conversionservice'
            id: reference('Microsoft.Web/connections/conversionservice', '2016-06-01').api.id
          }
          office365: {
            connectionId: office365Connection.id
            connectionName: 'office365'
            id: reference('Microsoft.Web/connections/office365', '2016-06-01').api.id
          }
        }
      }
    }
  }
}

resource requestTrigger 'Microsoft.Logic/workflows/triggers@2019-05-01' existing = {
  name: 'manual'
  parent: requestOpenAIResponseLogicApp
}
