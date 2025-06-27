import React, { useEffect, useRef, useState, useContext } from 'react';
import mermaid from 'mermaid';
import { ZoomIn, ZoomOut, RotateCcw } from 'lucide-react';
import { Button } from '~/components/ui/Button';
import { ThemeContext, isDark } from '~/hooks/ThemeContext';
import { cn } from '~/utils';

interface MermaidRendererProps {
  content: string;
  className?: string;
}

const MermaidRenderer: React.FC<MermaidRendererProps> = ({ content, className = '' }) => {
  const mermaidRef = useRef<HTMLDivElement>(null);
  const [isRendered, setIsRendered] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [scale, setScale] = useState(1);
  const { theme } = useContext(ThemeContext);
  const isDarkMode = isDark(theme);

  useEffect(() => {
    const initializeMermaid = () => {
      mermaid.initialize({
        startOnLoad: false,
        theme: isDarkMode ? 'dark' : 'default',
        suppressErrorRendering: true,
        securityLevel: 'sandbox',
        themeVariables: isDarkMode
          ? {
              background: '#1f2937',
              primaryColor: '#3b4c6b',
              secondaryColor: '#4b5c7c',
              tertiaryColor: '#5b6c8c',
              primaryTextColor: '#e5e7eb',
              secondaryTextColor: '#d1d5db',
              lineColor: '#6b7280',
              fontSize: '14px',
              nodeBorder: '#6b7280',
              mainBkg: '#374151',
              altBackground: '#4b5563',
              textColor: '#e5e7eb',
              edgeLabelBackground: '#374151',
              clusterBkg: '#374151',
              clusterBorder: '#6b7280',
              labelBoxBkgColor: '#4b5563',
              labelBoxBorderColor: '#6b7280',
              labelTextColor: '#e5e7eb',
            }
          : {
              background: '#ffffff',
              primaryColor: '#2563eb',
              secondaryColor: '#3b82f6',
              tertiaryColor: '#60a5fa',
              primaryTextColor: '#1f2937',
              secondaryTextColor: '#374151',
              lineColor: '#6b7280',
              fontSize: '14px',
              nodeBorder: '#d1d5db',
              mainBkg: '#f9fafb',
              altBackground: '#f3f4f6',
              textColor: '#1f2937',
              edgeLabelBackground: '#ffffff',
              clusterBkg: '#f9fafb',
              clusterBorder: '#d1d5db',
              labelBoxBkgColor: '#f3f4f6',
              labelBoxBorderColor: '#d1d5db',
              labelTextColor: '#1f2937',
            },
        flowchart: {
          curve: 'basis',
          nodeSpacing: 50,
          rankSpacing: 50,
          diagramPadding: 8,
          htmlLabels: true,
          useMaxWidth: true,
          padding: 15,
          wrappingWidth: 200,
        },
      });
    };

    const renderDiagram = async () => {
      if (mermaidRef.current && content.trim()) {
        try {
          setError(null);
          setIsRendered(false);

          // Clear previous content
          mermaidRef.current.innerHTML = '';

          const { svg } = await mermaid.render(`mermaid-${Date.now()}`, content.trim());
          mermaidRef.current.innerHTML = svg;

          // Style the SVG for better inline display
          const svgElement = mermaidRef.current.querySelector('svg');
          if (svgElement) {
            svgElement.style.maxWidth = '100%';
            svgElement.style.height = 'auto';
            svgElement.style.display = 'block';
            svgElement.style.margin = '0 auto';

            // Apply scaling
            if (scale !== 1) {
              svgElement.style.transform = `scale(${scale})`;
              svgElement.style.transformOrigin = '50% 50%';
            }
          }

          setIsRendered(true);
        } catch (err) {
          console.error('Mermaid rendering error:', err);
          setError(err instanceof Error ? err.message : 'Failed to render diagram');
          mermaidRef.current.innerHTML = '';
        }
      }
    };

    initializeMermaid();
    renderDiagram();
  }, [content, isDarkMode, scale]);

  const handleZoomIn = () => {
    setScale((prev) => Math.min(prev + 0.2, 2));
  };

  const handleZoomOut = () => {
    setScale((prev) => Math.max(prev - 0.2, 0.4));
  };

  const handleReset = () => {
    setScale(1);
  };

  if (error) {
    return (
      <div
        className={cn(
          'rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-400',
          className,
        )}
      >
        <div className="font-medium">{'Mermaid Diagram Error:'}</div>
        <div className="mt-1">{error}</div>
        <details className="mt-2">
          <summary className="cursor-pointer font-medium">{'Show diagram code'}</summary>
          <pre className="mt-2 whitespace-pre-wrap rounded bg-red-100 p-2 text-xs dark:bg-red-900/40">
            {content}
          </pre>
        </details>
      </div>
    );
  }

  return (
    <div
      className={cn(
        'relative rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800',
        className,
      )}
    >
      {/* Controls */}
      <div className="absolute right-2 top-2 z-10 flex gap-1 opacity-70 transition-opacity hover:opacity-100">
        <Button
          size="sm"
          variant="ghost"
          onClick={handleZoomOut}
          disabled={scale <= 0.4}
          className="h-7 w-7 p-0"
        >
          <ZoomOut className="h-3 w-3" />
        </Button>
        <Button
          size="sm"
          variant="ghost"
          onClick={handleZoomIn}
          disabled={scale >= 2}
          className="h-7 w-7 p-0"
        >
          <ZoomIn className="h-3 w-3" />
        </Button>
        <Button
          size="sm"
          variant="ghost"
          onClick={handleReset}
          disabled={scale === 1}
          className="h-7 w-7 p-0"
        >
          <RotateCcw className="h-3 w-3" />
        </Button>
      </div>

      {/* Diagram */}
      <div
        ref={mermaidRef}
        className="flex min-h-[100px] items-center justify-center overflow-auto"
        style={{
          transition: 'transform 0.2s ease-in-out',
        }}
      />

      {!isRendered && !error && (
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="text-sm text-gray-500 dark:text-gray-400">Rendering diagram...</div>
        </div>
      )}
    </div>
  );
};

export default MermaidRenderer;
