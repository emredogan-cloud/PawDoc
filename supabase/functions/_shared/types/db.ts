// =============================================================================
// AUTO-GENERATED — DO NOT EDIT
// =============================================================================
// Regenerate with:
//   supabase start  # if not already running
//   supabase gen types typescript --local > supabase/functions/_shared/types/db.ts
//
// CI does not regenerate this. The committed copy is the contract used by
// edge functions; if migrations change the schema, regenerate and commit.
// =============================================================================
// deno-fmt-ignore-file

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      analyses: {
        Row: {
          ai_latency_ms: number | null
          confidence_score: number | null
          created_at: string
          embedding: string | null
          emergency_override_applied: boolean
          full_response: Json | null
          id: string
          input_storage_key: string | null
          input_type: string
          model_used: string | null
          pet_id: string | null
          primary_concern: string | null
          text_description: string | null
          tier_used: number | null
          triage_level: string | null
          user_id: string
        }
        Insert: {
          ai_latency_ms?: number | null
          confidence_score?: number | null
          created_at?: string
          embedding?: string | null
          emergency_override_applied?: boolean
          full_response?: Json | null
          id?: string
          input_storage_key?: string | null
          input_type: string
          model_used?: string | null
          pet_id?: string | null
          primary_concern?: string | null
          text_description?: string | null
          tier_used?: number | null
          triage_level?: string | null
          user_id: string
        }
        Update: {
          ai_latency_ms?: number | null
          confidence_score?: number | null
          created_at?: string
          embedding?: string | null
          emergency_override_applied?: boolean
          full_response?: Json | null
          id?: string
          input_storage_key?: string | null
          input_type?: string
          model_used?: string | null
          pet_id?: string | null
          primary_concern?: string | null
          text_description?: string | null
          tier_used?: number | null
          triage_level?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "analyses_pet_id_fkey"
            columns: ["pet_id"]
            isOneToOne: false
            referencedRelation: "pets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "analyses_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      analysis_feedback: {
        Row: {
          analysis_id: string
          comment: string | null
          created_at: string
          id: string
          outcome: string | null
          rating: number | null
        }
        Insert: {
          analysis_id: string
          comment?: string | null
          created_at?: string
          id?: string
          outcome?: string | null
          rating?: number | null
        }
        Update: {
          analysis_id?: string
          comment?: string | null
          created_at?: string
          id?: string
          outcome?: string | null
          rating?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "analysis_feedback_analysis_id_fkey"
            columns: ["analysis_id"]
            isOneToOne: false
            referencedRelation: "analyses"
            referencedColumns: ["id"]
          },
        ]
      }
      health_events: {
        Row: {
          created_at: string
          event_date: string
          event_type: string
          id: string
          metadata: Json | null
          notes: string | null
          pet_id: string
        }
        Insert: {
          created_at?: string
          event_date: string
          event_type: string
          id?: string
          metadata?: Json | null
          notes?: string | null
          pet_id: string
        }
        Update: {
          created_at?: string
          event_date?: string
          event_type?: string
          id?: string
          metadata?: Json | null
          notes?: string | null
          pet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "health_events_pet_id_fkey"
            columns: ["pet_id"]
            isOneToOne: false
            referencedRelation: "pets"
            referencedColumns: ["id"]
          },
        ]
      }
      pets: {
        Row: {
          birth_date: string | null
          breed: string | null
          created_at: string
          id: string
          is_active: boolean
          medical_notes: string | null
          name: string
          photo_url: string | null
          sex: string | null
          species: string
          user_id: string
          weight_kg: number | null
        }
        Insert: {
          birth_date?: string | null
          breed?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          medical_notes?: string | null
          name: string
          photo_url?: string | null
          sex?: string | null
          species: string
          user_id: string
          weight_kg?: number | null
        }
        Update: {
          birth_date?: string | null
          breed?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          medical_notes?: string | null
          name?: string
          photo_url?: string | null
          sex?: string | null
          species?: string
          user_id?: string
          weight_kg?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "pets_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      referrals: {
        Row: {
          converted: boolean
          converted_at: string | null
          created_at: string
          id: string
          referral_code: string
          referred_email: string | null
          referrer_user_id: string
        }
        Insert: {
          converted?: boolean
          converted_at?: string | null
          created_at?: string
          id?: string
          referral_code: string
          referred_email?: string | null
          referrer_user_id: string
        }
        Update: {
          converted?: boolean
          converted_at?: string | null
          created_at?: string
          id?: string
          referral_code?: string
          referred_email?: string | null
          referrer_user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "referrals_referrer_user_id_fkey"
            columns: ["referrer_user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      reminders: {
        Row: {
          created_at: string
          due_date: string
          id: string
          is_sent: boolean
          notification_sent_at: string | null
          pet_id: string
          reminder_type: string
          user_id: string
        }
        Insert: {
          created_at?: string
          due_date: string
          id?: string
          is_sent?: boolean
          notification_sent_at?: string | null
          pet_id: string
          reminder_type: string
          user_id: string
        }
        Update: {
          created_at?: string
          due_date?: string
          id?: string
          is_sent?: boolean
          notification_sent_at?: string | null
          pet_id?: string
          reminder_type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reminders_pet_id_fkey"
            columns: ["pet_id"]
            isOneToOne: false
            referencedRelation: "pets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reminders_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          created_at: string
          email: string | null
          free_analyses_reset_at: string
          free_analyses_used_this_month: number
          id: string
          last_active_at: string
          one_signal_player_id: string | null
          preferred_locale: string
          revenuecat_user_id: string | null
          subscription_status: string
          subscription_tier: string | null
        }
        Insert: {
          created_at?: string
          email?: string | null
          free_analyses_reset_at?: string
          free_analyses_used_this_month?: number
          id: string
          last_active_at?: string
          one_signal_player_id?: string | null
          preferred_locale?: string
          revenuecat_user_id?: string | null
          subscription_status?: string
          subscription_tier?: string | null
        }
        Update: {
          created_at?: string
          email?: string | null
          free_analyses_reset_at?: string
          free_analyses_used_this_month?: number
          id?: string
          last_active_at?: string
          one_signal_player_id?: string | null
          preferred_locale?: string
          revenuecat_user_id?: string | null
          subscription_status?: string
          subscription_tier?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      attempt_consume_free_analysis: {
        Args: { p_monthly_limit?: number; p_user_id: string }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const

