# Invoke-GroupMessageTrace

## SYNOPSIS
Initiates a message trace for specified group types in batches.

## DESCRIPTION
The `Invoke-GroupMessageTrace` function allows administrators to perform message traces for various group types within Microsoft Exchange Online. This function enables tracking of messages sent and received by distribution lists, dynamic distribution lists, M365 groups, or all group types collectively.

The tracing can be configured to process groups in specified batch sizes, making it efficient for larger environments. The function retrieves groups based on the specified `GroupType` and initiates message trace reports for the last defined number of days. This provides deeper insight into message flow and any potential issues. The option to include outbound message traces offers further visibility into emails sent from groups where the group acts as the sender.

## PARAMETERS

### BatchSize
Specifies the number of groups to process in each batch, allowing for efficient processing in large environments.  
- **Type**: string  
- **Required**: No  
- **Default Value**: 100  
- **Accepted Values**: Must be between 1 and 100.  

### DaysBack
Determines how many days in the past the message traces should cover, helping to identify issues over a specific time frame.  
- **Type**: string  
- **Required**: No  
- **Default Value**: 90  
- **Accepted Values**: Any positive integer representing the number of days to look back.  

### GroupType
Specifies the type of groups to include in the trace, allowing for targeted analysis based on group type.  
- **Type**: string  
- **Required**: No  
- **Default Value**: AllGroups  
- **Accepted Values**:
  - `DistributionList`
  - `DynamicDistributionList`
  - `M365Group`
  - `AllGroups`  

### IncludeOutbound
This option allows you to include outbound message traces for selected groups, providing valuable insights into emails sent from those groups. This refers specifically to instances where the group serves as the sender address, utilizing 'Send As' or 'Send on Behalf' permissions. 
- **Type**: string  
- **Required**: No  
- **Default Value**:   
- **Accepted Values**: 
  - `True` (includes outbound message traces)
  - `False` (excludes outbound message traces)  

## EXAMPLES

### Example 1
```powershell
Invoke-GroupMessageTrace -BatchSize 50 -DaysBack 30 -GroupType "M365Group" -IncludeOutbound
```
*Initiates a message trace for M365 Groups over the last 30 days, processing 50 groups at a time, and includes outbound message traces.*

### Example 2
```powershell
Invoke-GroupMessageTrace -BatchSize 100 -DaysBack 60 -GroupType "AllGroups"
```
*Initiates a message trace for all group types over the last 60 days, processing 100 groups at a time, without including outbound messages.*

### Example 3
```powershell
Invoke-GroupMessageTrace -BatchSize 20 -DaysBack 14 -GroupType "DistributionList" -IncludeOutbound
```
*Initiates a message trace for Distribution Lists over the last 14 days, processing 20 groups at a time, and includes outbound message traces.*

## INPUTS
None. This function does not accept pipeline input.

## OUTPUTS
None. The function initiates a message trace report for the specified groups, which includes both received and optionally sent messages, depending on the `IncludeOutbound` parameter.

## NOTES
This function requires appropriate permissions to execute and access group information within the Microsoft Exchange Online environment. Ensure that the necessary modules are imported and authenticated prior to running this function.
