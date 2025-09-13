# Dayly App - Agent Prompt Template

## Recommended Prompt Structure for Each Phase

### Option 1: Focused Phase Implementation (Recommended)

```markdown
You are implementing Phase [X] of the Dayly app - a photo sharing app where users share one photo per day with small groups.

## Your Specific Task: [Phase Name]
[One paragraph description of what this phase accomplishes]

## Context
- Tech Stack: iOS (SwiftUI) + Python (FastAPI) + Supabase
- Previous phases have completed: [list completed items]
- You have access to: [list available APIs/interfaces]

## Deliverables
Please implement the following exact files:

### Backend:
1. `backend/app/api/[feature].py` - [description]
2. `backend/app/services/[service].py` - [description]

### iOS:
1. `Dayly/Features/[Feature]/[File].swift` - [description]

## Implementation Requirements
[Detailed requirements from implementation plan]

## Interfaces to Implement
[Copy exact interfaces from plan]

## Success Criteria
- [ ] [Specific testable criteria]
- [ ] [Another criteria]

## Please:
1. Implement all files completely
2. Include error handling
3. Add comments for complex logic
4. Follow existing code patterns
5. Write basic tests

Do not implement features from other phases.
```

### Option 2: Paired Implementation (For Related Features)

```markdown
You are implementing the [Feature] system for Dayly app, covering both iOS and backend.

## Overview
[Feature description]

## Part 1: Backend API
Implement these endpoints:
- POST /api/[endpoint]
- GET /api/[endpoint]

Requirements:
[Specific requirements]

## Part 2: iOS Implementation  
Implement:
- View: [ViewName]
- Service: [ServiceName]
- Models: [ModelNames]

Requirements:
[Specific requirements]

## Integration
Ensure iOS correctly calls backend APIs with proper error handling.

Please implement all files with complete functionality.
```

### Option 3: Single Platform Focus

```markdown
You are implementing the iOS portion of Phase [X] for the Dayly app.

## Context
The backend API is already complete with these endpoints:
[List endpoints with request/response formats]

## Your Task
Implement the iOS client code to:
1. [Specific task]
2. [Another task]

## Files to Create
[List specific files with descriptions]

## UI/UX Requirements
[Include any mockups or detailed descriptions]

Please ensure all code follows SwiftUI best practices and handles all API error cases.
```

## Tips for Effective Agent Use

### DO:
1. **Be Specific**: List exact file paths and function names
2. **Provide Context**: Include relevant completed work
3. **Define Success**: Clear, testable criteria
4. **Include Examples**: Show expected API responses, UI states
5. **Set Boundaries**: Explicitly state what NOT to implement

### DON'T:
1. **Overload**: Keep each prompt focused on 3-5 files max
2. **Assume Knowledge**: Include all necessary interfaces
3. **Skip Testing**: Always ask for basic test cases
4. **Forget Integration**: Specify how parts connect

## Example of What Works Well

```markdown
Implement the photo upload system for Dayly. 

You need to:
1. Create a FastAPI endpoint that accepts image uploads
2. Validate file size (max 10MB) and type (JPEG/PNG/HEIF)
3. Upload to Supabase Storage bucket named 'photos'
4. Save metadata to database
5. Return photo ID and expiration time

Here's the exact database schema:
[Include schema]

Here's the expected API contract:
[Include request/response examples]

Please implement:
- `backend/app/api/photos.py` with the upload endpoint
- Include error handling for: file too large, invalid type, storage failure
- Add logging for debugging
```

## Iterative Improvement

After each phase:
1. Test the implementation
2. Note any deviations from plan
3. Update shared context
4. Adjust next phase prompt based on learnings

## Common Issues and Solutions

**Issue**: Agent implements too much
**Solution**: Be explicit about boundaries, list what NOT to do

**Issue**: Missing error handling
**Solution**: Include specific error cases in requirements

**Issue**: Inconsistent with previous phases
**Solution**: Provide more context, include code examples

**Issue**: Incomplete implementation
**Solution**: Break into smaller sub-tasks, be more specific

Remember: Specific, focused prompts yield better results than comprehensive but vague instructions.
