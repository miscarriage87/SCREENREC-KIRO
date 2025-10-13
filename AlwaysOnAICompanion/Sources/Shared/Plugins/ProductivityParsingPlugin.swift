import Foundation
import CoreGraphics

/// Plugin for parsing productivity applications like Jira, Salesforce, etc.
public class ProductivityParsingPlugin: BaseParsingPlugin {
    
    public init() {
        super.init(
            identifier: "com.alwayson.plugins.productivity",
            name: "Productivity Application Parser",
            version: "1.1.0",
            description: "Enhanced parsing for productivity tools like Jira, Salesforce, Slack, Notion, Asana, and office applications with advanced workflow pattern recognition",
            supportedApplications: [
                "com.atlassian.jira",
                "com.atlassian.*", // All Atlassian products
                "com.salesforce.*", // Wildcard for Salesforce apps
                "com.microsoft.office.*",
                "com.tinyspeck.slackmacgap", // Slack
                "com.slack.*",
                "notion.id", // Notion
                "com.asana.*", // Asana
                "com.google.chrome", // For web-based productivity tools
                "com.apple.Safari",
                "com.microsoft.teams", // Microsoft Teams
                "com.monday.*", // Monday.com
                "com.trello.*", // Trello
                "com.airtable.*" // Airtable
            ]
        )
    }
    
    // MARK: - Productivity-Specific Parsing
    
    public override func enhanceOCRResults(
        _ results: [OCRResult],
        context: ApplicationContext,
        frame: CGImage
    ) async throws -> [EnhancedOCRResult] {
        var enhancedResults = try await super.enhanceOCRResults(results, context: context, frame: frame)
        
        // Detect application-specific elements
        if isJiraContext(context) {
            enhancedResults.append(contentsOf: detectJiraElements(in: results))
            enhancedResults.append(contentsOf: detectJiraWorkflowPatterns(in: results))
        } else if isSalesforceContext(context) {
            enhancedResults.append(contentsOf: detectSalesforceElements(in: results))
            enhancedResults.append(contentsOf: detectSalesforceWorkflowPatterns(in: results))
        } else if isOfficeContext(context) {
            enhancedResults.append(contentsOf: detectOfficeElements(in: results))
        } else if isSlackContext(context) {
            enhancedResults.append(contentsOf: detectSlackElements(in: results))
        } else if isNotionContext(context) {
            enhancedResults.append(contentsOf: detectNotionElements(in: results))
        } else if isAsanaContext(context) {
            enhancedResults.append(contentsOf: detectAsanaElements(in: results))
        }
        
        // Common productivity elements
        enhancedResults.append(contentsOf: detectWorkflowElements(in: results))
        enhancedResults.append(contentsOf: detectStatusElements(in: results))
        enhancedResults.append(contentsOf: detectPriorityElements(in: results))
        enhancedResults.append(contentsOf: detectFormElements(in: results))
        enhancedResults.append(contentsOf: detectProgressIndicators(in: results))
        
        return enhancedResults
    }
    
    public override func extractStructuredData(
        from results: [OCRResult],
        context: ApplicationContext
    ) async throws -> [StructuredDataElement] {
        var structuredData = try await super.extractStructuredData(from: results, context: context)
        
        // Extract application-specific structured data
        if isJiraContext(context) {
            structuredData.append(contentsOf: extractJiraData(from: results))
            structuredData.append(contentsOf: extractJiraWorkflowData(from: results))
        } else if isSalesforceContext(context) {
            structuredData.append(contentsOf: extractSalesforceData(from: results))
            structuredData.append(contentsOf: extractSalesforceWorkflowData(from: results))
        } else if isSlackContext(context) {
            structuredData.append(contentsOf: extractSlackData(from: results))
        } else if isNotionContext(context) {
            structuredData.append(contentsOf: extractNotionData(from: results))
        } else if isAsanaContext(context) {
            structuredData.append(contentsOf: extractAsanaData(from: results))
        }
        
        // Extract common productivity data
        structuredData.append(contentsOf: extractTaskData(from: results))
        structuredData.append(contentsOf: extractTimeTrackingData(from: results))
        structuredData.append(contentsOf: extractAssignmentData(from: results))
        structuredData.append(contentsOf: extractWorkflowPatterns(from: results))
        structuredData.append(contentsOf: extractFormData(from: results))
        
        return structuredData
    }
    
    // MARK: - Context Detection
    
    private func isJiraContext(_ context: ApplicationContext) -> Bool {
        return context.bundleID.contains("jira") ||
               context.windowTitle.localizedCaseInsensitiveContains("jira") ||
               context.windowTitle.localizedCaseInsensitiveContains("atlassian")
    }
    
    private func isSalesforceContext(_ context: ApplicationContext) -> Bool {
        return context.bundleID.contains("salesforce") ||
               context.windowTitle.localizedCaseInsensitiveContains("salesforce") ||
               context.windowTitle.localizedCaseInsensitiveContains("lightning")
    }
    
    private func isOfficeContext(_ context: ApplicationContext) -> Bool {
        return context.bundleID.contains("microsoft.office") ||
               context.bundleID.contains("word") ||
               context.bundleID.contains("excel") ||
               context.bundleID.contains("powerpoint")
    }
    
    private func isSlackContext(_ context: ApplicationContext) -> Bool {
        return context.bundleID.contains("slack") ||
               context.windowTitle.localizedCaseInsensitiveContains("slack")
    }
    
    private func isNotionContext(_ context: ApplicationContext) -> Bool {
        return context.bundleID.contains("notion") ||
               context.windowTitle.localizedCaseInsensitiveContains("notion")
    }
    
    private func isAsanaContext(_ context: ApplicationContext) -> Bool {
        return context.bundleID.contains("asana") ||
               context.windowTitle.localizedCaseInsensitiveContains("asana")
    }
    
    // MARK: - Jira-Specific Detection
    
    private func detectJiraWorkflowPatterns(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect workflow transitions
            if isJiraTransition(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "jira_transition",
                    structuredData: [
                        "transition_type": classifyJiraTransition(text),
                        "is_workflow_action": true
                    ]
                ))
            }
            
            // Detect board columns
            if isJiraBoardColumn(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "jira_board_column",
                    structuredData: [
                        "column_type": classifyBoardColumn(text),
                        "workflow_stage": mapColumnToWorkflowStage(text)
                    ]
                ))
            }
            
            // Detect epic links
            if isJiraEpicLink(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "jira_epic_link",
                    structuredData: [
                        "epic_key": extractEpicKey(text)
                    ]
                ))
            }
            
            // Detect component information
            if isJiraComponent(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "jira_component",
                    structuredData: [
                        "component_category": classifyComponent(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectJiraElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect issue keys (e.g., PROJ-123)
            if isJiraIssueKey(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "jira_issue_key",
                    structuredData: [
                        "project": extractProjectFromIssueKey(text),
                        "issue_number": extractIssueNumberFromKey(text)
                    ]
                ))
            }
            
            // Detect issue types
            if isJiraIssueType(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "jira_issue_type",
                    structuredData: [
                        "type_category": classifyJiraIssueType(text)
                    ]
                ))
            }
            
            // Detect sprint information
            if isJiraSprintInfo(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "jira_sprint",
                    structuredData: [
                        "sprint_name": extractSprintName(text),
                        "sprint_state": extractSprintState(text)
                    ]
                ))
            }
            
            // Detect story points
            if isStoryPoints(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "jira_story_points",
                    structuredData: [
                        "points": extractStoryPoints(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func extractJiraData(from results: [OCRResult]) -> [StructuredDataElement] {
        var data: [StructuredDataElement] = []
        
        // Extract issue information
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isJiraIssueKey(text) {
                data.append(StructuredDataElement(
                    id: "\(identifier)_jira_issue_\(UUID().uuidString)",
                    type: "jira_issue",
                    value: text,
                    metadata: [
                        "project": extractProjectFromIssueKey(text),
                        "issue_number": extractIssueNumberFromKey(text),
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return data
    }
    
    // MARK: - Salesforce-Specific Detection
    
    private func detectSalesforceElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect record IDs
            if isSalesforceRecordId(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "salesforce_record_id",
                    structuredData: [
                        "object_type": inferSalesforceObjectType(text)
                    ]
                ))
            }
            
            // Detect opportunity stages
            if isOpportunityStage(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "salesforce_opportunity_stage",
                    structuredData: [
                        "stage_category": classifyOpportunityStage(text)
                    ]
                ))
            }
            
            // Detect lead status
            if isLeadStatus(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "salesforce_lead_status",
                    structuredData: [
                        "status_category": classifyLeadStatus(text)
                    ]
                ))
            }
            
            // Detect currency amounts
            if isCurrencyAmount(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "salesforce_currency",
                    structuredData: [
                        "amount": extractCurrencyAmount(text),
                        "currency": extractCurrency(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func extractSalesforceData(from results: [OCRResult]) -> [StructuredDataElement] {
        var data: [StructuredDataElement] = []
        
        // Extract opportunity data
        let fieldPairs = extractFieldPairs(from: results)
        for pair in fieldPairs {
            guard let value = pair.value else { continue }
            
            let labelText = pair.label.text.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n"))
            
            if isSalesforceField(labelText) {
                data.append(StructuredDataElement(
                    id: "\(identifier)_sf_field_\(UUID().uuidString)",
                    type: "salesforce_field",
                    value: value.text,
                    metadata: [
                        "field_name": labelText,
                        "field_type": inferSalesforceFieldType(labelText),
                        "confidence": min(pair.label.confidence, value.confidence)
                    ],
                    boundingBox: pair.label.boundingBox.union(value.boundingBox)
                ))
            }
        }
        
        return data
    }
    
    private func detectSalesforceWorkflowPatterns(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect workflow rules and processes
            if isSalesforceWorkflowRule(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "salesforce_workflow_rule",
                    structuredData: [
                        "rule_type": classifyWorkflowRule(text),
                        "is_active": isActiveWorkflowRule(text)
                    ]
                ))
            }
            
            // Detect approval processes
            if isApprovalProcess(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "salesforce_approval_process",
                    structuredData: [
                        "approval_stage": extractApprovalStage(text),
                        "requires_approval": true
                    ]
                ))
            }
            
            // Detect pipeline stages
            if isPipelineStage(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "salesforce_pipeline_stage",
                    structuredData: [
                        "stage_probability": extractStageProbability(text),
                        "stage_category": classifyPipelineStage(text)
                    ]
                ))
            }
            
            // Detect territory management
            if isTerritoryInfo(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "salesforce_territory",
                    structuredData: [
                        "territory_type": classifyTerritory(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    // MARK: - Office-Specific Detection
    
    private func detectOfficeElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect document sections
            if isDocumentSection(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "document_section",
                    structuredData: [
                        "section_level": inferSectionLevel(text, result.boundingBox)
                    ]
                ))
            }
            
            // Detect table headers
            if isTableHeader(text, result.boundingBox) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "table_header",
                    structuredData: [
                        "column_type": inferColumnType(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    // MARK: - Slack-Specific Detection
    
    private func detectSlackElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect channel names
            if isSlackChannel(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "slack_channel",
                    structuredData: [
                        "channel_type": classifySlackChannel(text),
                        "is_private": isPrivateChannel(text)
                    ]
                ))
            }
            
            // Detect mentions
            if isSlackMention(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "slack_mention",
                    structuredData: [
                        "mention_type": classifyMention(text),
                        "username": extractUsername(text)
                    ]
                ))
            }
            
            // Detect thread indicators
            if isSlackThread(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "slack_thread",
                    structuredData: [
                        "thread_count": extractThreadCount(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    // MARK: - Notion-Specific Detection
    
    private func detectNotionElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect database properties
            if isNotionProperty(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "notion_property",
                    structuredData: [
                        "property_type": inferNotionPropertyType(text)
                    ]
                ))
            }
            
            // Detect page hierarchies
            if isNotionPageHierarchy(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "notion_page_hierarchy",
                    structuredData: [
                        "hierarchy_level": extractHierarchyLevel(text)
                    ]
                ))
            }
            
            // Detect block types
            if isNotionBlock(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "notion_block",
                    structuredData: [
                        "block_type": classifyNotionBlock(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    // MARK: - Asana-Specific Detection
    
    private func detectAsanaElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect project sections
            if isAsanaSection(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "asana_section",
                    structuredData: [
                        "section_type": classifyAsanaSection(text)
                    ]
                ))
            }
            
            // Detect task dependencies
            if isAsanaDependency(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "asana_dependency",
                    structuredData: [
                        "dependency_type": classifyDependency(text)
                    ]
                ))
            }
            
            // Detect custom fields
            if isAsanaCustomField(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "asana_custom_field",
                    structuredData: [
                        "field_type": inferAsanaFieldType(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    // MARK: - Common Productivity Elements
    
    private func detectWorkflowElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect workflow states
            if isWorkflowState(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "workflow_state",
                    structuredData: [
                        "state_category": classifyWorkflowState(text),
                        "is_terminal": isTerminalState(text)
                    ]
                ))
            }
            
            // Detect action buttons
            if isActionButton(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "action_button",
                    structuredData: [
                        "action_type": classifyActionType(text),
                        "is_destructive": isDestructiveAction(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectStatusElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isStatusIndicator(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "status_indicator",
                    structuredData: [
                        "status_type": classifyStatusType(text),
                        "severity": determineStatusSeverity(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectPriorityElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isPriorityIndicator(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "priority_indicator",
                    structuredData: [
                        "priority_level": extractPriorityLevel(text),
                        "priority_value": normalizePriorityValue(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectFormElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect form validation messages
            if isValidationMessage(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "form_validation",
                    structuredData: [
                        "validation_type": classifyValidationType(text),
                        "is_error": isErrorValidation(text)
                    ]
                ))
            }
            
            // Detect required field indicators
            if isRequiredFieldIndicator(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "required_field",
                    structuredData: [
                        "is_required": true
                    ]
                ))
            }
            
            // Detect dropdown options
            if isDropdownOption(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "dropdown_option",
                    structuredData: [
                        "option_category": classifyDropdownOption(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectProgressIndicators(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect percentage completion
            if isPercentageCompletion(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "progress_percentage",
                    structuredData: [
                        "completion_percentage": extractPercentage(text),
                        "progress_type": inferProgressType(text)
                    ]
                ))
            }
            
            // Detect milestone indicators
            if isMilestone(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "milestone",
                    structuredData: [
                        "milestone_type": classifyMilestone(text),
                        "is_completed": isMilestoneCompleted(text)
                    ]
                ))
            }
            
            // Detect deadline information
            if isDeadline(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "deadline",
                    structuredData: [
                        "deadline_urgency": assessDeadlineUrgency(text),
                        "is_overdue": isOverdue(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    // MARK: - Data Extraction Helpers
    
    private func extractTaskData(from results: [OCRResult]) -> [StructuredDataElement] {
        var tasks: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isTaskTitle(text) {
                tasks.append(StructuredDataElement(
                    id: "\(identifier)_task_\(UUID().uuidString)",
                    type: "task",
                    value: text,
                    metadata: [
                        "task_type": inferTaskType(text),
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return tasks
    }
    
    private func extractTimeTrackingData(from results: [OCRResult]) -> [StructuredDataElement] {
        var timeData: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isTimeValue(text) {
                timeData.append(StructuredDataElement(
                    id: "\(identifier)_time_\(UUID().uuidString)",
                    type: "time_tracking",
                    value: text,
                    metadata: [
                        "time_type": inferTimeType(text),
                        "duration_minutes": extractDurationInMinutes(text),
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return timeData
    }
    
    private func extractAssignmentData(from results: [OCRResult]) -> [StructuredDataElement] {
        var assignments: [StructuredDataElement] = []
        
        let fieldPairs = extractFieldPairs(from: results)
        for pair in fieldPairs {
            guard let value = pair.value else { continue }
            
            let labelText = pair.label.text.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n"))
            
            if isAssignmentField(labelText) {
                assignments.append(StructuredDataElement(
                    id: "\(identifier)_assignment_\(UUID().uuidString)",
                    type: "assignment",
                    value: value.text,
                    metadata: [
                        "assignment_type": classifyAssignmentType(labelText),
                        "assignee": value.text,
                        "confidence": min(pair.label.confidence, value.confidence)
                    ],
                    boundingBox: pair.label.boundingBox.union(value.boundingBox)
                ))
            }
        }
        
        return assignments
    }
    
    private func extractJiraWorkflowData(from results: [OCRResult]) -> [StructuredDataElement] {
        var workflowData: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isJiraTransition(text) {
                workflowData.append(StructuredDataElement(
                    id: "\(identifier)_jira_transition_\(UUID().uuidString)",
                    type: "jira_workflow_transition",
                    value: text,
                    metadata: [
                        "transition_type": classifyJiraTransition(text),
                        "workflow_stage": mapTransitionToStage(text),
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return workflowData
    }
    
    private func extractSalesforceWorkflowData(from results: [OCRResult]) -> [StructuredDataElement] {
        var workflowData: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isApprovalProcess(text) {
                workflowData.append(StructuredDataElement(
                    id: "\(identifier)_sf_approval_\(UUID().uuidString)",
                    type: "salesforce_approval_process",
                    value: text,
                    metadata: [
                        "approval_stage": extractApprovalStage(text),
                        "requires_approval": true,
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return workflowData
    }
    
    private func extractSlackData(from results: [OCRResult]) -> [StructuredDataElement] {
        var slackData: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isSlackChannel(text) {
                slackData.append(StructuredDataElement(
                    id: "\(identifier)_slack_channel_\(UUID().uuidString)",
                    type: "slack_channel",
                    value: text,
                    metadata: [
                        "channel_type": classifySlackChannel(text),
                        "is_private": isPrivateChannel(text),
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return slackData
    }
    
    private func extractNotionData(from results: [OCRResult]) -> [StructuredDataElement] {
        var notionData: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isNotionProperty(text) {
                notionData.append(StructuredDataElement(
                    id: "\(identifier)_notion_property_\(UUID().uuidString)",
                    type: "notion_property",
                    value: text,
                    metadata: [
                        "property_type": inferNotionPropertyType(text),
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return notionData
    }
    
    private func extractAsanaData(from results: [OCRResult]) -> [StructuredDataElement] {
        var asanaData: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isAsanaSection(text) {
                asanaData.append(StructuredDataElement(
                    id: "\(identifier)_asana_section_\(UUID().uuidString)",
                    type: "asana_section",
                    value: text,
                    metadata: [
                        "section_type": classifyAsanaSection(text),
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return asanaData
    }
    
    private func extractWorkflowPatterns(from results: [OCRResult]) -> [StructuredDataElement] {
        var patterns: [StructuredDataElement] = []
        
        // Detect sequential workflow patterns
        let sortedResults = results.sorted { $0.boundingBox.origin.y < $1.boundingBox.origin.y }
        var workflowSequence: [OCRResult] = []
        
        for result in sortedResults {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isWorkflowStep(text) {
                workflowSequence.append(result)
            } else if !workflowSequence.isEmpty {
                // End of sequence, create pattern
                if workflowSequence.count >= 2 {
                    let sequenceText = workflowSequence.map { $0.text }.joined(separator: " → ")
                    patterns.append(StructuredDataElement(
                        id: "\(identifier)_workflow_pattern_\(UUID().uuidString)",
                        type: "workflow_pattern",
                        value: sequenceText,
                        metadata: [
                            "step_count": workflowSequence.count,
                            "pattern_type": classifyWorkflowPattern(workflowSequence),
                            "confidence": workflowSequence.map { $0.confidence }.min() ?? 0.0
                        ],
                        boundingBox: workflowSequence.reduce(workflowSequence[0].boundingBox) { $0.union($1.boundingBox) }
                    ))
                }
                workflowSequence.removeAll()
            }
        }
        
        return patterns
    }
    
    private func extractFormData(from results: [OCRResult]) -> [StructuredDataElement] {
        var formData: [StructuredDataElement] = []
        
        // Group form elements by proximity
        let formGroups = groupFormElements(results)
        
        for group in formGroups {
            if group.count >= 2 { // At least one label-value pair
                let formText = group.map { $0.text }.joined(separator: " | ")
                formData.append(StructuredDataElement(
                    id: "\(identifier)_form_group_\(UUID().uuidString)",
                    type: "form_group",
                    value: formText,
                    metadata: [
                        "field_count": group.count / 2, // Approximate field count
                        "form_type": inferFormType(group),
                        "confidence": group.map { $0.confidence }.min() ?? 0.0
                    ],
                    boundingBox: group.reduce(group[0].boundingBox) { $0.union($1.boundingBox) }
                ))
            }
        }
        
        return formData
    }
    
    // MARK: - Helper Methods
    
    // Jira helpers
    private func isJiraIssueKey(_ text: String) -> Bool {
        return text.matches(#"[A-Z]+-\d+"#)
    }
    
    private func extractProjectFromIssueKey(_ text: String) -> String {
        return String(text.split(separator: "-").first ?? "")
    }
    
    private func extractIssueNumberFromKey(_ text: String) -> Int {
        let components = text.split(separator: "-")
        return Int(components.last ?? "0") ?? 0
    }
    
    private func isJiraIssueType(_ text: String) -> Bool {
        let issueTypes = ["Story", "Bug", "Task", "Epic", "Subtask", "Improvement"]
        return issueTypes.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyJiraIssueType(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("bug") { return "defect" }
        if lowercased.contains("story") { return "feature" }
        if lowercased.contains("epic") { return "epic" }
        if lowercased.contains("task") { return "task" }
        return "other"
    }
    
    private func isJiraSprintInfo(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("sprint") ||
               text.matches(#"Sprint \d+"#)
    }
    
    private func extractSprintName(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractSprintState(_ text: String) -> String {
        if text.localizedCaseInsensitiveContains("active") { return "active" }
        if text.localizedCaseInsensitiveContains("closed") { return "closed" }
        if text.localizedCaseInsensitiveContains("future") { return "future" }
        return "unknown"
    }
    
    private func isStoryPoints(_ text: String) -> Bool {
        return text.matches(#"^\d+(\.\d+)?\s*(pts?|points?)?$"#)
    }
    
    private func extractStoryPoints(_ text: String) -> Double {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(numbers) ?? 0.0
    }
    
    // Salesforce helpers
    private func isSalesforceRecordId(_ text: String) -> Bool {
        return text.matches(#"[a-zA-Z0-9]{15,18}"#) && text.count >= 15
    }
    
    private func inferSalesforceObjectType(_ recordId: String) -> String {
        // Salesforce record IDs have prefixes that indicate object type
        let prefix = String(recordId.prefix(3))
        switch prefix {
        case "001": return "Account"
        case "003": return "Contact"
        case "006": return "Opportunity"
        case "00Q": return "Lead"
        case "500": return "Case"
        default: return "Unknown"
        }
    }
    
    private func isOpportunityStage(_ text: String) -> Bool {
        let stages = ["Prospecting", "Qualification", "Needs Analysis", "Value Proposition", 
                     "Proposal", "Negotiation", "Closed Won", "Closed Lost"]
        return stages.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyOpportunityStage(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("closed won") { return "won" }
        if lowercased.contains("closed lost") { return "lost" }
        if lowercased.contains("proposal") || lowercased.contains("negotiation") { return "late_stage" }
        return "early_stage"
    }
    
    private func isLeadStatus(_ text: String) -> Bool {
        let statuses = ["New", "Working", "Nurturing", "Qualified", "Unqualified"]
        return statuses.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyLeadStatus(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("qualified") { return "qualified" }
        if lowercased.contains("unqualified") { return "unqualified" }
        if lowercased.contains("working") || lowercased.contains("nurturing") { return "in_progress" }
        return "new"
    }
    
    private func isCurrencyAmount(_ text: String) -> Bool {
        return text.matches(#"[\$€£¥]\s*[\d,]+(\.\d{2})?"#)
    }
    
    private func extractCurrencyAmount(_ text: String) -> Double {
        let cleanedText = text.replacingOccurrences(of: ",", with: "")
        let numberString = cleanedText.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted).joined()
        return Double(numberString) ?? 0.0
    }
    
    private func extractCurrency(_ text: String) -> String {
        if text.contains("$") { return "USD" }
        if text.contains("€") { return "EUR" }
        if text.contains("£") { return "GBP" }
        if text.contains("¥") { return "JPY" }
        return "USD"
    }
    
    private func isSalesforceField(_ label: String) -> Bool {
        let sfFields = ["Account Name", "Contact Name", "Opportunity Name", "Amount", 
                       "Close Date", "Stage", "Lead Source", "Owner"]
        return sfFields.contains { label.localizedCaseInsensitiveContains($0) }
    }
    
    private func inferSalesforceFieldType(_ label: String) -> String {
        let lowercased = label.lowercased()
        if lowercased.contains("date") { return "date" }
        if lowercased.contains("amount") || lowercased.contains("value") { return "currency" }
        if lowercased.contains("name") { return "text" }
        if lowercased.contains("stage") || lowercased.contains("status") { return "picklist" }
        return "text"
    }
    
    // Common productivity helpers
    private func isWorkflowState(_ text: String) -> Bool {
        let states = ["To Do", "In Progress", "Done", "Blocked", "Review", "Testing", "Approved", "Rejected"]
        return states.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyWorkflowState(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("to do") || lowercased.contains("new") { return "initial" }
        if lowercased.contains("progress") || lowercased.contains("working") { return "active" }
        if lowercased.contains("done") || lowercased.contains("complete") { return "complete" }
        if lowercased.contains("blocked") || lowercased.contains("waiting") { return "blocked" }
        return "intermediate"
    }
    
    private func isTerminalState(_ text: String) -> Bool {
        let terminalStates = ["Done", "Complete", "Closed", "Resolved", "Cancelled", "Rejected"]
        return terminalStates.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func isActionButton(_ text: String) -> Bool {
        let actions = ["Create", "Edit", "Delete", "Save", "Cancel", "Submit", "Approve", "Reject", "Assign"]
        return actions.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyActionType(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("create") || lowercased.contains("add") { return "create" }
        if lowercased.contains("edit") || lowercased.contains("update") { return "update" }
        if lowercased.contains("delete") || lowercased.contains("remove") { return "delete" }
        if lowercased.contains("save") || lowercased.contains("submit") { return "save" }
        return "action"
    }
    
    private func isDestructiveAction(_ text: String) -> Bool {
        let destructiveActions = ["Delete", "Remove", "Cancel", "Reject"]
        return destructiveActions.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func isStatusIndicator(_ text: String) -> Bool {
        let statuses = ["Active", "Inactive", "Pending", "Complete", "Failed", "Success", "Warning", "Error"]
        return statuses.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyStatusType(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("success") || lowercased.contains("complete") { return "success" }
        if lowercased.contains("error") || lowercased.contains("failed") { return "error" }
        if lowercased.contains("warning") || lowercased.contains("pending") { return "warning" }
        return "info"
    }
    
    private func determineStatusSeverity(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("error") || lowercased.contains("failed") { return "high" }
        if lowercased.contains("warning") { return "medium" }
        return "low"
    }
    
    private func isPriorityIndicator(_ text: String) -> Bool {
        let priorities = ["High", "Medium", "Low", "Critical", "Urgent", "Normal", "P1", "P2", "P3", "P4"]
        return priorities.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func extractPriorityLevel(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("critical") || lowercased.contains("p1") { return "critical" }
        if lowercased.contains("high") || lowercased.contains("urgent") || lowercased.contains("p2") { return "high" }
        if lowercased.contains("medium") || lowercased.contains("normal") || lowercased.contains("p3") { return "medium" }
        if lowercased.contains("low") || lowercased.contains("p4") { return "low" }
        return "medium"
    }
    
    private func normalizePriorityValue(_ text: String) -> Int {
        let level = extractPriorityLevel(text)
        switch level {
        case "critical": return 4
        case "high": return 3
        case "medium": return 2
        case "low": return 1
        default: return 2
        }
    }
    
    // Document helpers
    private func isDocumentSection(_ text: String) -> Bool {
        return text.matches(#"^\d+(\.\d+)*\s+"#) || // Numbered sections
               (text.count < 100 && text.count > 5 && !text.contains("."))
    }
    
    private func inferSectionLevel(_ text: String, _ bounds: CGRect) -> Int {
        if text.matches(#"^\d+\s+"#) { return 1 }
        if text.matches(#"^\d+\.\d+\s+"#) { return 2 }
        if text.matches(#"^\d+\.\d+\.\d+\s+"#) { return 3 }
        
        // Infer from position and formatting
        if bounds.origin.y < 100 { return 1 }
        if bounds.origin.y < 200 { return 2 }
        return 3
    }
    
    private func isTableHeader(_ text: String, _ bounds: CGRect) -> Bool {
        // Table headers are typically short, at the top of tables
        return text.count < 50 && !text.contains("\n") && bounds.origin.y < 300
    }
    
    private func inferColumnType(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("date") || lowercased.contains("time") { return "date" }
        if lowercased.contains("amount") || lowercased.contains("price") || lowercased.contains("cost") { return "currency" }
        if lowercased.contains("count") || lowercased.contains("number") || lowercased.contains("qty") { return "number" }
        return "text"
    }
    
    // Task helpers
    private func isTaskTitle(_ text: String) -> Bool {
        return text.count > 10 && text.count < 200 && !text.hasSuffix(":")
    }
    
    private func inferTaskType(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("bug") || lowercased.contains("fix") { return "bug" }
        if lowercased.contains("feature") || lowercased.contains("implement") { return "feature" }
        if lowercased.contains("test") || lowercased.contains("verify") { return "test" }
        if lowercased.contains("document") || lowercased.contains("write") { return "documentation" }
        return "task"
    }
    
    // Time tracking helpers
    private func isTimeValue(_ text: String) -> Bool {
        return text.matches(#"\d+[hm]"#) || // 2h, 30m
               text.matches(#"\d+:\d+"#) || // 2:30
               text.matches(#"\d+\.\d+h"#) // 2.5h
    }
    
    private func inferTimeType(_ text: String) -> String {
        if text.localizedCaseInsensitiveContains("logged") { return "logged" }
        if text.localizedCaseInsensitiveContains("remaining") { return "remaining" }
        if text.localizedCaseInsensitiveContains("estimate") { return "estimate" }
        return "duration"
    }
    
    private func extractDurationInMinutes(_ text: String) -> Int {
        if text.contains("h") && text.contains("m") {
            // Format like "2h 30m"
            let hours = Int(text.components(separatedBy: "h")[0]) ?? 0
            let minutes = Int(text.components(separatedBy: "h")[1].components(separatedBy: "m")[0].trimmingCharacters(in: .whitespaces)) ?? 0
            return hours * 60 + minutes
        } else if text.contains("h") {
            // Format like "2h" or "2.5h"
            let hoursString = text.replacingOccurrences(of: "h", with: "")
            let hours = Double(hoursString) ?? 0.0
            return Int(hours * 60)
        } else if text.contains("m") {
            // Format like "30m"
            let minutesString = text.replacingOccurrences(of: "m", with: "")
            return Int(minutesString) ?? 0
        } else if text.contains(":") {
            // Format like "2:30"
            let components = text.split(separator: ":")
            let hours = Int(components[0]) ?? 0
            let minutes = Int(components[1]) ?? 0
            return hours * 60 + minutes
        }
        
        return 0
    }
    
    // Assignment helpers
    private func isAssignmentField(_ label: String) -> Bool {
        let assignmentFields = ["Assignee", "Owner", "Reporter", "Responsible", "Assigned to"]
        return assignmentFields.contains { label.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyAssignmentType(_ label: String) -> String {
        let lowercased = label.lowercased()
        if lowercased.contains("assignee") || lowercased.contains("assigned") { return "assignee" }
        if lowercased.contains("owner") { return "owner" }
        if lowercased.contains("reporter") { return "reporter" }
        if lowercased.contains("responsible") { return "responsible" }
        return "assignment"
    }
    
    // MARK: - Enhanced Jira Helpers
    
    private func isJiraTransition(_ text: String) -> Bool {
        let transitions = ["Start Progress", "Stop Progress", "Done", "Resolve", "Close", "Reopen", "In Review"]
        return transitions.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyJiraTransition(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("start") || lowercased.contains("begin") { return "start" }
        if lowercased.contains("stop") || lowercased.contains("pause") { return "pause" }
        if lowercased.contains("done") || lowercased.contains("complete") { return "complete" }
        if lowercased.contains("resolve") { return "resolve" }
        return "transition"
    }
    
    private func isJiraBoardColumn(_ text: String) -> Bool {
        let columns = ["To Do", "In Progress", "Code Review", "Testing", "Done", "Backlog"]
        return columns.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func classifyBoardColumn(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("backlog") { return "backlog" }
        if lowercased.contains("to do") || lowercased.contains("todo") { return "todo" }
        if lowercased.contains("progress") { return "in_progress" }
        if lowercased.contains("review") { return "review" }
        if lowercased.contains("test") { return "testing" }
        if lowercased.contains("done") { return "done" }
        return "other"
    }
    
    private func mapColumnToWorkflowStage(_ text: String) -> String {
        let columnType = classifyBoardColumn(text)
        switch columnType {
        case "backlog": return "planning"
        case "todo": return "ready"
        case "in_progress": return "active"
        case "review", "testing": return "validation"
        case "done": return "complete"
        default: return "intermediate"
        }
    }
    
    private func isJiraEpicLink(_ text: String) -> Bool {
        return text.matches(#"Epic:\s*[A-Z]+-\d+"#) || text.localizedCaseInsensitiveContains("epic link")
    }
    
    private func extractEpicKey(_ text: String) -> String {
        if let range = text.range(of: #"[A-Z]+-\d+"#, options: .regularExpression) {
            return String(text[range])
        }
        return ""
    }
    
    private func isJiraComponent(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("component") && text.count < 100
    }
    
    private func classifyComponent(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("frontend") || lowercased.contains("ui") { return "frontend" }
        if lowercased.contains("backend") || lowercased.contains("api") { return "backend" }
        if lowercased.contains("database") || lowercased.contains("db") { return "database" }
        return "general"
    }
    
    private func mapTransitionToStage(_ text: String) -> String {
        let transitionType = classifyJiraTransition(text)
        switch transitionType {
        case "start": return "active"
        case "pause": return "blocked"
        case "complete", "resolve": return "complete"
        default: return "intermediate"
        }
    }
    
    // MARK: - Enhanced Salesforce Helpers
    
    private func isSalesforceWorkflowRule(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("workflow rule") ||
               text.localizedCaseInsensitiveContains("process builder")
    }
    
    private func classifyWorkflowRule(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("field update") { return "field_update" }
        if lowercased.contains("email alert") { return "email_alert" }
        if lowercased.contains("task") { return "task_creation" }
        return "general"
    }
    
    private func isActiveWorkflowRule(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("active") && !text.localizedCaseInsensitiveContains("inactive")
    }
    
    private func isApprovalProcess(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("approval") ||
               text.localizedCaseInsensitiveContains("pending approval") ||
               text.localizedCaseInsensitiveContains("approved") ||
               text.localizedCaseInsensitiveContains("rejected")
    }
    
    private func extractApprovalStage(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("pending") { return "pending" }
        if lowercased.contains("approved") { return "approved" }
        if lowercased.contains("rejected") { return "rejected" }
        if lowercased.contains("recalled") { return "recalled" }
        return "unknown"
    }
    
    private func isPipelineStage(_ text: String) -> Bool {
        let stages = ["Prospecting", "Qualification", "Needs Analysis", "Proposal", "Negotiation", "Closed Won", "Closed Lost"]
        return stages.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func extractStageProbability(_ text: String) -> Int {
        // Map common stages to probabilities
        let lowercased = text.lowercased()
        if lowercased.contains("prospecting") { return 10 }
        if lowercased.contains("qualification") { return 25 }
        if lowercased.contains("needs analysis") { return 50 }
        if lowercased.contains("proposal") { return 75 }
        if lowercased.contains("negotiation") { return 90 }
        if lowercased.contains("closed won") { return 100 }
        if lowercased.contains("closed lost") { return 0 }
        return 50
    }
    
    private func classifyPipelineStage(_ text: String) -> String {
        let probability = extractStageProbability(text)
        if probability == 0 { return "lost" }
        if probability == 100 { return "won" }
        if probability >= 75 { return "late_stage" }
        if probability >= 50 { return "mid_stage" }
        return "early_stage"
    }
    
    private func isTerritoryInfo(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("territory") ||
               text.localizedCaseInsensitiveContains("region")
    }
    
    private func classifyTerritory(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("north") || lowercased.contains("south") ||
           lowercased.contains("east") || lowercased.contains("west") { return "geographic" }
        if lowercased.contains("enterprise") || lowercased.contains("smb") { return "segment" }
        return "general"
    }
    
    // MARK: - Slack Helpers
    
    private func isSlackChannel(_ text: String) -> Bool {
        return text.hasPrefix("#") || text.localizedCaseInsensitiveContains("channel")
    }
    
    private func classifySlackChannel(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("general") { return "general" }
        if lowercased.contains("random") { return "social" }
        if lowercased.contains("dev") || lowercased.contains("engineering") { return "development" }
        if lowercased.contains("marketing") { return "marketing" }
        if lowercased.contains("support") { return "support" }
        return "topic"
    }
    
    private func isPrivateChannel(_ text: String) -> Bool {
        return text.contains("🔒") || text.localizedCaseInsensitiveContains("private")
    }
    
    private func isSlackMention(_ text: String) -> Bool {
        return text.hasPrefix("@") || text.contains("@")
    }
    
    private func classifyMention(_ text: String) -> String {
        if text.contains("@channel") || text.contains("@here") { return "channel_mention" }
        if text.contains("@everyone") { return "everyone_mention" }
        return "user_mention"
    }
    
    private func extractUsername(_ text: String) -> String {
        if let range = text.range(of: #"@\w+"#, options: .regularExpression) {
            return String(text[range]).replacingOccurrences(of: "@", with: "")
        }
        return ""
    }
    
    private func isSlackThread(_ text: String) -> Bool {
        return text.matches(#"\d+\s+repl(y|ies)"#) || text.localizedCaseInsensitiveContains("thread")
    }
    
    private func extractThreadCount(_ text: String) -> Int {
        if let range = text.range(of: #"\d+"#, options: .regularExpression) {
            return Int(String(text[range])) ?? 0
        }
        return 0
    }
    
    // MARK: - Notion Helpers
    
    private func isNotionProperty(_ text: String) -> Bool {
        let properties = ["Status", "Assignee", "Due Date", "Priority", "Tags", "Created", "Last Edited"]
        return properties.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func inferNotionPropertyType(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("date") { return "date" }
        if lowercased.contains("status") { return "select" }
        if lowercased.contains("assignee") || lowercased.contains("person") { return "person" }
        if lowercased.contains("tag") { return "multi_select" }
        if lowercased.contains("number") || lowercased.contains("count") { return "number" }
        return "text"
    }
    
    private func isNotionPageHierarchy(_ text: String) -> Bool {
        return text.matches(#"^\s*[▶▼]\s+"#) || text.contains("└") || text.contains("├")
    }
    
    private func extractHierarchyLevel(_ text: String) -> Int {
        let leadingSpaces = text.prefix(while: { $0 == " " || $0 == "\t" }).count
        return max(1, leadingSpaces / 2) // Assume 2 spaces per level
    }
    
    private func isNotionBlock(_ text: String) -> Bool {
        return text.hasPrefix("# ") || text.hasPrefix("## ") || text.hasPrefix("- ") || text.hasPrefix("1. ")
    }
    
    private func classifyNotionBlock(_ text: String) -> String {
        if text.hasPrefix("# ") { return "heading_1" }
        if text.hasPrefix("## ") { return "heading_2" }
        if text.hasPrefix("### ") { return "heading_3" }
        if text.hasPrefix("- ") { return "bulleted_list" }
        if text.matches(#"^\d+\.\s"#) { return "numbered_list" }
        if text.hasPrefix("> ") { return "quote" }
        return "paragraph"
    }
    
    // MARK: - Asana Helpers
    
    private func isAsanaSection(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("section") ||
               (text.count < 50 && text.uppercased() == text && !text.contains(" "))
    }
    
    private func classifyAsanaSection(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("todo") || lowercased.contains("to do") { return "todo" }
        if lowercased.contains("progress") || lowercased.contains("doing") { return "in_progress" }
        if lowercased.contains("done") || lowercased.contains("complete") { return "complete" }
        if lowercased.contains("review") { return "review" }
        return "custom"
    }
    
    private func isAsanaDependency(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("depends on") ||
               text.localizedCaseInsensitiveContains("blocked by") ||
               text.localizedCaseInsensitiveContains("waiting for")
    }
    
    private func classifyDependency(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("blocked") { return "blocking" }
        if lowercased.contains("waiting") { return "waiting" }
        if lowercased.contains("depends") { return "dependency" }
        return "related"
    }
    
    private func isAsanaCustomField(_ text: String) -> Bool {
        return text.contains(":") && text.count < 100 && !isUILabel(text)
    }
    
    private func inferAsanaFieldType(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("date") { return "date" }
        if lowercased.contains("priority") { return "enum" }
        if lowercased.contains("effort") || lowercased.contains("points") { return "number" }
        return "text"
    }
    
    // MARK: - Enhanced Form Helpers
    
    private func isValidationMessage(_ text: String) -> Bool {
        let validationKeywords = ["required", "invalid", "error", "must", "cannot", "please"]
        return validationKeywords.contains { text.localizedCaseInsensitiveContains($0) } && text.count < 200
    }
    
    private func classifyValidationType(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("required") { return "required" }
        if lowercased.contains("format") || lowercased.contains("invalid") { return "format" }
        if lowercased.contains("length") || lowercased.contains("character") { return "length" }
        if lowercased.contains("match") || lowercased.contains("confirm") { return "match" }
        return "general"
    }
    
    private func isErrorValidation(_ text: String) -> Bool {
        let errorKeywords = ["error", "invalid", "incorrect", "failed"]
        return errorKeywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
    
    private func isRequiredFieldIndicator(_ text: String) -> Bool {
        return text.contains("*") || text.localizedCaseInsensitiveContains("required")
    }
    
    private func isDropdownOption(_ text: String) -> Bool {
        return text.contains("▼") || text.contains("⌄") || 
               (text.count < 50 && !text.contains(":") && !text.contains("\n"))
    }
    
    private func classifyDropdownOption(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("select") { return "placeholder" }
        if lowercased.contains("all") || lowercased.contains("any") { return "filter" }
        return "option"
    }
    
    // MARK: - Progress Indicator Helpers
    
    private func isPercentageCompletion(_ text: String) -> Bool {
        return text.matches(#"\d+%"#) || text.matches(#"\d+/\d+"#)
    }
    
    private func extractPercentage(_ text: String) -> Int {
        if text.contains("%") {
            let numberString = text.replacingOccurrences(of: "%", with: "")
            return Int(numberString) ?? 0
        } else if text.contains("/") {
            let components = text.split(separator: "/")
            if components.count == 2,
               let numerator = Int(components[0]),
               let denominator = Int(components[1]),
               denominator > 0 {
                return Int((Double(numerator) / Double(denominator)) * 100)
            }
        }
        return 0
    }
    
    private func inferProgressType(_ text: String) -> String {
        if text.localizedCaseInsensitiveContains("complete") { return "completion" }
        if text.localizedCaseInsensitiveContains("progress") { return "progress" }
        if text.contains("/") { return "fraction" }
        return "percentage"
    }
    
    private func isMilestone(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("milestone") ||
               text.contains("🏁") || text.contains("📍")
    }
    
    private func classifyMilestone(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("release") { return "release" }
        if lowercased.contains("sprint") { return "sprint" }
        if lowercased.contains("phase") { return "phase" }
        return "general"
    }
    
    private func isMilestoneCompleted(_ text: String) -> Bool {
        return text.contains("✓") || text.contains("✅") || 
               text.localizedCaseInsensitiveContains("completed")
    }
    
    private func isDeadline(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("due") ||
               text.localizedCaseInsensitiveContains("deadline") ||
               text.localizedCaseInsensitiveContains("expires")
    }
    
    private func assessDeadlineUrgency(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("overdue") || lowercased.contains("late") { return "overdue" }
        if lowercased.contains("today") || lowercased.contains("urgent") { return "urgent" }
        if lowercased.contains("tomorrow") || lowercased.contains("soon") { return "high" }
        return "normal"
    }
    
    private func isOverdue(_ text: String) -> Bool {
        return text.localizedCaseInsensitiveContains("overdue") ||
               text.localizedCaseInsensitiveContains("late") ||
               text.contains("🔴")
    }
    
    // MARK: - Workflow Pattern Helpers
    
    private func isWorkflowStep(_ text: String) -> Bool {
        return text.matches(#"^\d+\."#) || // Numbered steps
               text.matches(#"^Step \d+"#) ||
               text.localizedCaseInsensitiveContains("then") ||
               text.localizedCaseInsensitiveContains("next")
    }
    
    private func classifyWorkflowPattern(_ sequence: [OCRResult]) -> String {
        let texts = sequence.map { $0.text.lowercased() }
        
        if texts.contains(where: { $0.contains("approve") }) { return "approval_workflow" }
        if texts.contains(where: { $0.contains("review") }) { return "review_workflow" }
        if texts.contains(where: { $0.contains("test") }) { return "testing_workflow" }
        if texts.contains(where: { $0.contains("deploy") }) { return "deployment_workflow" }
        
        return "general_workflow"
    }
    
    private func groupFormElements(_ results: [OCRResult]) -> [[OCRResult]] {
        var groups: [[OCRResult]] = []
        var currentGroup: [OCRResult] = []
        
        let sortedResults = results.sorted { $0.boundingBox.origin.y < $1.boundingBox.origin.y }
        
        for result in sortedResults {
            if isUILabel(result.text) || isFieldValue(result.text) {
                if currentGroup.isEmpty {
                    currentGroup.append(result)
                } else {
                    let lastResult = currentGroup.last!
                    let verticalDistance = result.boundingBox.origin.y - lastResult.boundingBox.maxY
                    
                    if verticalDistance < 50 { // Within 50 points vertically
                        currentGroup.append(result)
                    } else {
                        if currentGroup.count >= 2 {
                            groups.append(currentGroup)
                        }
                        currentGroup = [result]
                    }
                }
            }
        }
        
        if currentGroup.count >= 2 {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    private func inferFormType(_ group: [OCRResult]) -> String {
        let texts = group.map { $0.text.lowercased() }
        
        if texts.contains(where: { $0.contains("login") || $0.contains("password") }) { return "login_form" }
        if texts.contains(where: { $0.contains("contact") || $0.contains("email") }) { return "contact_form" }
        if texts.contains(where: { $0.contains("payment") || $0.contains("card") }) { return "payment_form" }
        if texts.contains(where: { $0.contains("search") }) { return "search_form" }
        
        return "general_form"
    }
}

// MARK: - String Extension for Regex (if not already defined)

private extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}