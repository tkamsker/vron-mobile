# GraphQL Projects API Documentation for Flutter Mobile App

This document provides comprehensive documentation for querying projects using GraphQL in the VRon merchants application. It is designed to help Flutter developers integrate project listing and details functionality.

## Table of Contents

1. [Overview](#overview)
2. [GraphQL Endpoint](#graphql-endpoint)
3. [Authentication](#authentication)
4. [Available Queries](#available-queries)
5. [Query Examples](#query-examples)
6. [Response Types](#response-types)
7. [Flutter Implementation Guide](#flutter-implementation-guide)
8. [Error Handling](#error-handling)

---

## Overview

The VRon API provides several ways to query projects:
- **`getProjects`** - Returns a list of basic project information
- **`getVRProject`** - Returns detailed VR project information for a specific project
- **`VRGetProjectsMinimal`** - Returns minimal project information (lightweight)

---

## GraphQL Endpoint

**Base URL:** `https://api.vron.stage.motorenflug.at/graphql`

The GraphQL endpoint accepts POST requests with JSON payloads containing the query and variables.

---

## Authentication

All project queries require authentication. Include the authentication token in the request headers:

```
Authorization: Bearer <your-auth-token>
```

Additionally, include the platform header:
```
X-VRon-Platform: merchants
```

---

## Available Queries

### 1. Get Projects List (`getProjects`)

Returns an array of projects with basic information including subscription details.

**Query Signature:**
```graphql
query GetProjects($input: VrGetProjectsInput!) {
  getProjects(input: $input) {
    # Project fields
  }
}
```

**Input Variables:**
```typescript
{
  input: {
    collaborationId?: string  // Optional: Filter by collaboration ID
  }
}
```

### 2. Get VR Project Details (`getVRProject`)

Returns detailed information about a specific VR project including assets, subscription, and VR-specific data.

**Query Signature:**
```graphql
query GetVRProject($input: VrGetProjectInput!, $lang: Language!) {
  getVRProject(input: $input) {
    # VrProject fields
  }
}
```

**Input Variables:**
```typescript
{
  input: {
    id: string  // Required: Project ID
  },
  lang: Language  // Required: Language enum (EN, DE, or PT)
}
```

### 3. Get Projects Minimal (`VRGetProjectsMinimal`)

Returns a lightweight list of projects with minimal fields (id, name, slug only).

**Query Signature:**
```graphql
query GetProjectsMinimal($input: VrGetProjectsInput!) {
  VRGetProjectsMinimal(input: $input) {
    projects {
      # Minimal fields
    }
  }
}
```

---

## Query Examples

### Example 1: Get All Projects (Basic)

```graphql
query GetProjects {
  getProjects(input: {}) {
    id
    slug
    imageUrl
    isLive
    liveDate
    name {
      text(lang: EN)
    }
    subscription {
      isActive
      isTrial
      status
      canChoosePlan
      hasExpired
      currency
      price
      renewalInterval
      startedAt
      expiresAt
      renewsAt
      prices {
        currency
        monthly
        yearly
      }
    }
  }
}
```

**Variables:**
```json
{}
```

### Example 2: Get Projects with Language Support

```graphql
query GetProjects($lang: Language!) {
  getProjects(input: {}) {
    id
    slug
    imageUrl
    isLive
    liveDate
    name {
      text(lang: $lang)
    }
    subscription {
      isActive
      isTrial
      status
      canChoosePlan
      hasExpired
      currency
      price
      renewalInterval
      startedAt
      expiresAt
      renewsAt
      prices {
        currency
        monthly
        yearly
      }
    }
  }
}
```

**Variables:**
```json
{
  "lang": "EN"
}
```

### Example 3: Get Detailed VR Project

```graphql
query GetVRProject($input: VrGetProjectInput!, $lang: Language!) {
  getVRProject(input: $input) {
    id
    slug
    name {
      text(lang: $lang)
    }
    description {
      text(lang: $lang)
    }
    imageUrl
    isLive
    liveDate
    isOwner
    isShop
    meshUrl
    worldUrl
    spawnCoordinates {
      position
      rotation
      scale
    }
    subscription {
      isActive
      isTrial
      status
      canChoosePlan
      renewalInterval
      prices {
        currency
        monthly
        yearly
      }
    }
    shopify {
      domain
    }
    vron {
      easterEgg
    }
    assets {
      id
      width
      height
      coordinates {
        position
        rotation
        scale
      }
      product {
        info {
          id
          title {
            text(lang: $lang)
          }
          price
        }
        media {
          images2D {
            name {
              text(lang: $lang)
            }
            url
            previewUrl
          }
          images360 {
            name {
              text(lang: $lang)
            }
            url
            previewUrl
          }
          items3DGlb {
            name {
              text(lang: $lang)
            }
            url
            previewUrl
          }
        }
        mediaId
        mediaRenderType
      }
      extras {
        type
        portal {
          projectId
          title {
            text(lang: $lang)
          }
        }
      }
    }
  }
}
```

**Variables:**
```json
{
  "input": {
    "id": "project-id-here"
  },
  "lang": "EN"
}
```

### Example 4: Get Projects Minimal (Lightweight)

```graphql
query GetProjectsMinimal {
  VRGetProjectsMinimal(input: {}) {
    projects {
      id
      name
      slug
    }
  }
}
```

**Variables:**
```json
{}
```

---

## Response Types

### Project Type

```typescript
type Project = {
  __typename: 'Project';
  id: string;                    // Unique project identifier
  slug: string;                  // URL-friendly project identifier
  imageUrl?: string | null;      // Project thumbnail/image URL
  isLive: boolean;               // Whether the project is currently live
  liveDate?: Date | null;        // Date when project went/will go live
  name: I18NField;               // Internationalized project name
  subscription: ProjectSubscription; // Subscription information
}
```

### I18NField Type

```typescript
type I18NField = {
  text(lang: Language): string;  // Get text in specified language
}

// Languages: EN, DE, PT
```

### ProjectSubscription Type

```typescript
type ProjectSubscription = {
  __typename: 'ProjectSubscription';
  isActive: boolean;                    // Whether subscription is active
  isTrial: boolean;                      // Whether currently in trial period
  status: SubscriptionStatus;            // Subscription status enum
  canChoosePlan: boolean;                // Whether user can choose a plan
  hasExpired: boolean;                    // Whether subscription has expired
  currency?: Currency | null;            // Currency (EUR, USD)
  price?: number | null;                 // Current subscription price
  renewalInterval?: SubscriptionRenewalInterval | null; // MONTHLY, YEARLY
  startedAt?: Date | null;               // When subscription started
  expiresAt?: Date | null;               // When subscription expires
  renewsAt?: Date | null;                // When subscription will renew
  prices: ProjectSubscriptionPrices;     // Pricing information
}
```

### ProjectSubscriptionPrices Type

```typescript
type ProjectSubscriptionPrices = {
  __typename: 'ProjectSubscriptionPrices';
  currency: Currency;    // EUR or USD
  monthly: number;      // Monthly subscription price
  yearly: number;       // Yearly subscription price
}
```

### VrProject Type (Detailed)

```typescript
type VrProject = {
  __typename: 'VRProject';
  id: string;
  slug: string;
  name: I18NField;
  description?: I18NField | null;
  imageUrl?: string | null;
  isLive: boolean;
  liveDate?: Date | null;
  isOwner: boolean;                    // Whether current user owns the project
  isShop: boolean;                     // Whether project has shop functionality
  meshUrl: string;                     // 3D mesh URL for VR rendering
  worldUrl: string;                    // World URL for VR access
  spawnCoordinates: VrSpatialCoordinates; // Spawn position in VR
  subscription: VrProjectSubscription;
  shopify?: VrProjectShopify | null;
  vron?: VrProjectVRon | null;
  assets: Array<VrAsset>;              // Array of assets placed in the project
}
```

### VrProjectSubscription Type

**Note:** This is a simplified version compared to `ProjectSubscription`. It has fewer fields.

```typescript
type VrProjectSubscription = {
  __typename: 'VRProjectSubscription';
  isActive: boolean;
  isTrial: boolean;
  status: string;                      // String (not enum) - subscription status
  canChoosePlan: boolean;
  renewalInterval?: SubscriptionRenewalInterval | null;
  prices: VrProjectSubscriptionPrice;
}
```

### VrProjectSubscriptionPrice Type

```typescript
type VrProjectSubscriptionPrice = {
  __typename: 'VRProjectSubscriptionPrice';
  currency: Currency;    // EUR or USD
  monthly: number;      // Monthly subscription price
  yearly: number;       // Yearly subscription price
}
```

### VrSpatialCoordinates Type

```typescript
type VrSpatialCoordinates = {
  __typename: 'VRSpatialCoordinates';
  position: string;  // 3D position (format: "x,y,z")
  rotation: string; // 3D rotation (format: "x,y,z")
  scale: string;    // 3D scale (format: "x,y,z")
}
```

### VrAsset Type

```typescript
type VrAsset = {
  __typename: 'VRAsset';
  id: string;
  width: string;
  height: string;
  coordinates: VrSpatialCoordinates;
  product?: VrAssetProduct | null;
  extras?: VrAssetExtras | null;
}
```

### VrAssetProduct Type

```typescript
type VrAssetProduct = {
  __typename: 'VRAssetProduct';
  info: VrAssetProductInfo;
  media: VrMedia;
  mediaId?: string | null;
  mediaRenderType: MediaRenderType;  // IMAGE_2D, IMAGE_2D_CAROUSEL, etc.
}
```

### VrMedia Type

```typescript
type VrMedia = {
  __typename: 'VRMedia';
  images2D: Array<VrMediaFile>;
  images360: Array<VrMediaFile>;
  items3DGlb: Array<VrMediaFile>;
}
```

### VrMediaFile Type

```typescript
type VrMediaFile = {
  __typename: 'VRMediaFile';
  name: I18NField;
  url: string;           // Full resolution URL
  previewUrl: string;    // Preview/thumbnail URL
}
```

### Enums

```typescript
enum Language {
  EN = 'EN'
  DE = 'DE'
  PT = 'PT'  // Note: PT may not be fully supported by backend yet
}

enum Currency {
  EUR = 'EUR'
  USD = 'USD'
}

enum SubscriptionStatus {
  ACTIVE = 'ACTIVE'
  CANCELLED = 'CANCELLED'
  NOT_STARTED = 'NOT_STARTED'
  PERMANENTLY_ACTIVE = 'PERMANENTLY_ACTIVE'
  RENEWAL_FAILED = 'RENEWAL_FAILED'
  TRIAL_EXPIRED = 'TRIAL_EXPIRED'
}

enum SubscriptionRenewalInterval {
  MONTHLY = 'MONTHLY'
  YEARLY = 'YEARLY'
}

enum MediaRenderType {
  IMAGE_2D = 'IMAGE_2D'
  IMAGE_2D_CAROUSEL = 'IMAGE_2D_CAROUSEL'
  IMAGE_360 = 'IMAGE_360'
  IMAGE_360_CAROUSEL = 'IMAGE_360_CAROUSEL'
  ITEM_3D_GLB = 'ITEM_3D_GLB'
  ITEM_3D_GLB_CAROUSEL = 'ITEM_3D_GLB_CAROUSEL'
  VIDEO = 'VIDEO'
  VIDEO_CAROUSEL = 'VIDEO_CAROUSEL'
}
```

---

## Flutter Implementation Guide

### Step 1: Setup GraphQL Client

```dart
import 'package:graphql_flutter/graphql_flutter.dart';

final HttpLink httpLink = HttpLink(
  'https://api.vron.stage.motorenflug.at/graphql',
);

final AuthLink authLink = AuthLink(
  getToken: () async => 'Bearer $yourAuthToken',
);

final Link link = authLink.concat(httpLink);

final GraphQLClient client = GraphQLClient(
  link: link,
  cache: GraphQLCache(),
);
```

### Step 2: Define Models

```dart
class Project {
  final String id;
  final String slug;
  final String? imageUrl;
  final bool isLive;
  final DateTime? liveDate;
  final String name; // Resolved from I18NField
  final ProjectSubscription subscription;

  Project({
    required this.id,
    required this.slug,
    this.imageUrl,
    required this.isLive,
    this.liveDate,
    required this.name,
    required this.subscription,
  });

  factory Project.fromJson(Map<String, dynamic> json, String lang) {
    return Project(
      id: json['id'] as String,
      slug: json['slug'] as String,
      imageUrl: json['imageUrl'] as String?,
      isLive: json['isLive'] as bool,
      liveDate: json['liveDate'] != null 
        ? DateTime.parse(json['liveDate']) 
        : null,
      name: json['name']['text'] as String,
      subscription: ProjectSubscription.fromJson(json['subscription']),
    );
  }
}

class ProjectSubscription {
  final bool isActive;
  final bool isTrial;
  final String status;
  final bool canChoosePlan;
  final bool hasExpired;
  final String? currency;
  final double? price;
  final String? renewalInterval;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? renewsAt;
  final ProjectSubscriptionPrices prices;

  ProjectSubscription({
    required this.isActive,
    required this.isTrial,
    required this.status,
    required this.canChoosePlan,
    required this.hasExpired,
    this.currency,
    this.price,
    this.renewalInterval,
    this.startedAt,
    this.expiresAt,
    this.renewsAt,
    required this.prices,
  });

  factory ProjectSubscription.fromJson(Map<String, dynamic> json) {
    return ProjectSubscription(
      isActive: json['isActive'] as bool,
      isTrial: json['isTrial'] as bool,
      status: json['status'] as String,
      canChoosePlan: json['canChoosePlan'] as bool,
      hasExpired: json['hasExpired'] as bool,
      currency: json['currency'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      renewalInterval: json['renewalInterval'] as String?,
      startedAt: json['startedAt'] != null 
        ? DateTime.parse(json['startedAt']) 
        : null,
      expiresAt: json['expiresAt'] != null 
        ? DateTime.parse(json['expiresAt']) 
        : null,
      renewsAt: json['renewsAt'] != null 
        ? DateTime.parse(json['renewsAt']) 
        : null,
      prices: ProjectSubscriptionPrices.fromJson(json['prices']),
    );
  }
}

class ProjectSubscriptionPrices {
  final String currency;
  final double monthly;
  final double yearly;

  ProjectSubscriptionPrices({
    required this.currency,
    required this.monthly,
    required this.yearly,
  });

  factory ProjectSubscriptionPrices.fromJson(Map<String, dynamic> json) {
    return ProjectSubscriptionPrices(
      currency: json['currency'] as String,
      monthly: (json['monthly'] as num).toDouble(),
      yearly: (json['yearly'] as num).toDouble(),
    );
  }
}
```

### Step 3: Create Query String

```dart
const String getProjectsQuery = '''
  query GetProjects(\$lang: Language!) {
    getProjects(input: {}) {
      id
      slug
      imageUrl
      isLive
      liveDate
      name {
        text(lang: \$lang)
      }
      subscription {
        isActive
        isTrial
        status
        canChoosePlan
        hasExpired
        currency
        price
        renewalInterval
        startedAt
        expiresAt
        renewsAt
        prices {
          currency
          monthly
          yearly
        }
      }
    }
  }
''';
```

### Step 4: Execute Query

```dart
Future<List<Project>> fetchProjects(String language) async {
  final QueryOptions options = QueryOptions(
    document: gql(getProjectsQuery),
    variables: {
      'lang': language, // 'EN', 'DE', or 'PT'
    },
    fetchPolicy: FetchPolicy.networkOnly,
  );

  final QueryResult result = await client.query(options);

  if (result.hasException) {
    throw Exception('Failed to fetch projects: ${result.exception}');
  }

  final List<dynamic> projectsData = result.data?['getProjects'] as List<dynamic>;
  
  return projectsData
      .map((json) => Project.fromJson(json as Map<String, dynamic>, language))
      .toList();
}
```

### Step 5: Usage in Flutter Widget

```dart
class ProjectsListWidget extends StatefulWidget {
  @override
  _ProjectsListWidgetState createState() => _ProjectsListWidgetState();
}

class _ProjectsListWidgetState extends State<ProjectsListWidget> {
  String language = 'EN'; // Get from user preferences
  List<Project>? projects;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final fetchedProjects = await fetchProjects(language);
      setState(() {
        projects = fetchedProjects;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(child: Text('Error: $error'));
    }

    if (projects == null || projects!.isEmpty) {
      return Center(child: Text('No projects found'));
    }

    return ListView.builder(
      itemCount: projects!.length,
      itemBuilder: (context, index) {
        final project = projects![index];
        return ListTile(
          leading: project.imageUrl != null
              ? Image.network(project.imageUrl!)
              : Icon(Icons.folder),
          title: Text(project.name),
          subtitle: Text('Slug: ${project.slug}'),
          trailing: project.isLive
              ? Icon(Icons.check_circle, color: Colors.green)
              : Icon(Icons.radio_button_unchecked),
          onTap: () {
            // Navigate to project details
          },
        );
      },
    );
  }
}
```

---

## Error Handling

### Common Errors

1. **NOT_AUTHENTICATED**
   - **Message:** "Oops! You need to be logged in to access this. Wanna try again?"
   - **Solution:** Ensure authentication token is valid and included in headers

2. **UNAUTHORIZED**
   - **Message:** "Hmm... looks like you don't have the necessary permissions for this action."
   - **Solution:** Check user roles and permissions

3. **TOKEN_EXPIRED**
   - **Message:** "Oops! Your session has expired. Please log in again."
   - **Solution:** Refresh authentication token

### Error Handling Example

```dart
try {
  final projects = await fetchProjects(language);
  // Handle success
} on GraphQLException catch (e) {
  if (e.graphqlErrors.isNotEmpty) {
    final errorCode = e.graphqlErrors.first.extensions?['code'];
    switch (errorCode) {
      case 'NOT_AUTHENTICATED':
        // Redirect to login
        break;
      case 'TOKEN_EXPIRED':
        // Refresh token and retry
        break;
      default:
        // Show error message
        break;
    }
  }
} catch (e) {
  // Handle network or other errors
}
```

---

## Additional Notes

1. **Language Support:**
   - Supported languages: `EN`, `DE`, `PT`
   - Always pass the `lang` variable when querying internationalized fields
   - Use `name.text(lang: $lang)` to get localized text

2. **Date Formats:**
   - Dates are returned as ISO 8601 strings (e.g., "2024-01-15T10:30:00Z")
   - Parse using `DateTime.parse()` in Flutter

3. **Nullability:**
   - Fields marked with `?` or `Maybe` can be `null`
   - Always check for null before using optional fields

4. **Pagination:**
   - Currently, `getProjects` returns all projects
   - Consider implementing client-side pagination for large lists

5. **Real-time Updates:**
   - For real-time project updates, consider using GraphQL subscriptions
   - WebSocket endpoint: `ws://api.vron.stage.motorenflug.at/graphql`

---

## Complete Query with All Fields

For reference, here's a complete query requesting all available fields:

```graphql
query GetProjectsComplete($lang: Language!) {
  getProjects(input: {}) {
    id
    slug
    imageUrl
    isLive
    liveDate
    name {
      text(lang: $lang)
    }
    subscription {
      isActive
      isTrial
      status
      canChoosePlan
      hasExpired
      currency
      price
      renewalInterval
      startedAt
      expiresAt
      renewsAt
      prices {
        currency
        monthly
        yearly
      }
    }
  }
}
```

---

## Support

For questions or issues:
- Check the GraphQL schema at the endpoint
- Review error messages in the response
- Ensure authentication tokens are valid
- Verify network connectivity

---

**Last Updated:** Based on codebase analysis
**API Version:** As of current codebase state

